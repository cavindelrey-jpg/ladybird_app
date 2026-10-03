-- supabase/scripts/clean_placeholder_content.sql
--
-- Removes machine-generated filler from what students see, on the SHARED
-- production project (also used by greenhills_app and academia-cameroon).
-- Run by a human in the Supabase SQL editor (or psql) -- deliberately NOT
-- a migration, because it changes live content.
--
-- Nothing is deleted. Rows are UNPUBLISHED and every change is recorded in
-- public.content_cleanup_log, so the whole run can be undone (see UNDO at
-- the bottom). The rules mirror lib/core/content_quality.dart, which the
-- app already applies client-side; validated on the content pipeline's
-- 243 quizzes (flags exactly the 50 generated ones, no false positives)
-- and on the 836 published courses.
--
-- STEP 1: run the PREVIEW block alone and read the numbers.
-- STEP 2: run the APPLY block.

create table if not exists public.content_cleanup_log (
  id bigserial primary key,
  run_label text not null,
  table_name text not null,
  row_id uuid not null,
  reason text not null,
  title text,
  logged_at timestamptz not null default now()
);
alter table public.content_cleanup_log enable row level security; -- no policies: service role / SQL editor only

-- ── Rules (mirror content_quality.dart) ──────────────────────────────────
create or replace function public._is_placeholder_question(q jsonb)
returns boolean language sql immutable as $$
  with p as (
    select lower(trim(coalesce(q->>'prompt', ''))) as prompt,
           coalesce(q->>'type', 'mcq') as type,
           coalesce((q->>'correctIndex')::int, 0) as ci,
           coalesce(array(select lower(trim(x)) from jsonb_array_elements_text(coalesce(q->'options', '[]'::jsonb)) x), '{}') as opts
  )
  select
    length(prompt) < 8
    or prompt ~ '(this is (question|q)\s*\d+|question\s*\d+\s*[.?:]?$|sample question|placeholder|lorem ipsum|insert question|what is an important concept in|important concept .* part \d+|what day of the course)'
    or (type = 'mcq' and (
          (select count(*) from unnest(opts) o where o <> '' and o !~ '^(option|choice|answer)?\s*[\(\[]?([a-e]|[1-5])[\)\].:]?$') < 2
       or (select count(distinct o) from unnest(opts) o) < cardinality(opts)
       or ci < 0 or ci >= cardinality(opts)))
  from p;
$$;

create or replace function public._is_placeholder_quiz(questions jsonb)
returns boolean language sql immutable as $$
  select case
    when jsonb_typeof(questions) <> 'array' or jsonb_array_length(questions) = 0 then true
    else
      (select count(*) filter (where public._is_placeholder_question(q)) * 2 >= count(*) from jsonb_array_elements(questions) q)
      or (jsonb_array_length(questions) >= 3 and
          (select count(distinct regexp_replace(lower(trim(q->>'prompt')), '\d+', '#', 'g')) from jsonb_array_elements(questions) q) = 1)
  end;
$$;

create or replace function public._is_placeholder_course(title text, body text, body_delta text, description text)
returns boolean language sql immutable as $$
  with x as (
    select lower(trim(coalesce(title, ''))) as t,
           lower(trim(trim(coalesce(nullif(trim(body), ''), body_delta, '')) || ' ' || trim(coalesce(description, '')))) as txt
  )
  select t = '' or length(txt) < 120
      or (txt ~ '(to be uploaded|coming soon|lorem ipsum|placeholder|content goes here|image needed:)' and length(txt) < 600)
      or t ~ '^(exploring )?(topic|lesson|course)\s*\d+$'
      or txt ~ '\m(topic|lesson|course) \d{3,}\M'
      or (txt ~ 'this concludes the introduction to' and length(txt) < 800)
  from x;
$$;

-- ═════════════════════════════ PREVIEW (read-only) ═══════════════════════
select 'quizzes to unpublish' as what, count(*) from public.tests
 where published and public._is_placeholder_quiz(questions)
union all
select 'quizzes kept', count(*) from public.tests
 where published and not public._is_placeholder_quiz(questions)
union all
select 'stub/filler courses to unpublish', count(*) from public.courses
 where published and public._is_placeholder_course(title, body, body_delta::text, description)
union all
select 'duplicate course copies to unpublish', count(*) from (
  select id, row_number() over (
           partition by lower(trim(title)), lower(trim(subject)), lower(trim(level))
           order by length(coalesce(nullif(trim(body), ''), body_delta::text, '')) desc,
                    (cover_image_url is not null) desc, enrolled_count desc, created_at asc) as rn
  from public.courses
  where published and not public._is_placeholder_course(title, body, body_delta::text, description)
) d where rn > 1;

-- Sample of what would go (check these look like filler):
select 'quiz' as kind, title, subject, topic from public.tests
 where published and public._is_placeholder_quiz(questions) limit 25;

-- ═══════════════════════════════ APPLY ═══════════════════════════════════
begin;

with victims as (
  select id, title from public.tests where published and public._is_placeholder_quiz(questions)
), logged as (
  insert into public.content_cleanup_log (run_label, table_name, row_id, reason, title)
  select '2026-10 placeholder cleanup', 'tests', id, 'placeholder quiz', title from victims
)
update public.tests t set published = false from victims v where t.id = v.id;

with victims as (
  select id, title from public.courses
   where published and public._is_placeholder_course(title, body, body_delta::text, description)
), logged as (
  insert into public.content_cleanup_log (run_label, table_name, row_id, reason, title)
  select '2026-10 placeholder cleanup', 'courses', id, 'stub course', title from victims
)
update public.courses c set published = false from victims v where c.id = v.id;

with ranked as (
  select id, title, row_number() over (
           partition by lower(trim(title)), lower(trim(subject)), lower(trim(level))
           order by length(coalesce(nullif(trim(body), ''), body_delta::text, '')) desc,
                    (cover_image_url is not null) desc, enrolled_count desc, created_at asc) as rn
  from public.courses where published
), victims as (select id, title from ranked where rn > 1),
logged as (
  insert into public.content_cleanup_log (run_label, table_name, row_id, reason, title)
  select '2026-10 placeholder cleanup', 'courses', id, 'duplicate course', title from victims
)
update public.courses c set published = false from victims v where c.id = v.id;

-- Real replacement quizzes (supabase/content/quizzes/*.json), inserted
-- only if a quiz with the same title doesn't already exist.
insert into public.tests (subject, title, description, difficulty, questions, created_by_name, published, category, topic)
select 'Biology', 'Genetics: Inheritance and Variation', 'Mendel''s laws, genotypes and phenotypes, monohybrid crosses, sex linkage and mutation.', 'medium'::test_difficulty,
       $q$[{"id": "q1", "type": "mcq", "prompt": "The physical expression of an organism's genes, such as eye colour, is called its…", "options": ["Genotype", "Phenotype", "Allele", "Locus"], "correctIndex": 1, "points": 10}, {"id": "q2", "type": "mcq", "prompt": "An organism with two identical alleles for a gene (e.g. TT) is described as…", "options": ["Hybrid", "Heterozygous", "Recessive", "Homozygous"], "correctIndex": 3, "points": 10}, {"id": "q3", "type": "mcq", "prompt": "Two heterozygous tall pea plants (Tt × Tt) are crossed. What is the expected phenotypic ratio of tall to short offspring?", "options": ["3 : 1", "1 : 1", "1 : 2 : 1", "All tall"], "correctIndex": 0, "points": 10}, {"id": "q4", "type": "mcq", "prompt": "In the cross Tt × Tt, what fraction of the offspring is expected to be heterozygous?", "options": ["3/4", "1/4", "1/2", "0"], "correctIndex": 2, "points": 10}, {"id": "q5", "type": "mcq", "prompt": "Which cross is used to find out whether a tall plant is TT or Tt?", "options": ["A cross with another tall plant", "A test cross with a homozygous recessive (tt) plant", "Self-pollination of a short plant", "A cross with a TT plant"], "correctIndex": 1, "points": 10}, {"id": "q6", "type": "mcq", "prompt": "In humans, the sex of a child is determined by…", "options": ["The temperature during pregnancy", "The mother's egg alone", "The number of autosomes", "The sex chromosome (X or Y) in the father's sperm"], "correctIndex": 3, "points": 10}, {"id": "q7", "type": "mcq", "prompt": "Haemophilia is more common in males because the gene is…", "options": ["Recessive and carried on the X chromosome", "Dominant and carried on the Y chromosome", "Carried on an autosome", "Caused by an extra chromosome"], "correctIndex": 0, "points": 10}, {"id": "q8", "type": "mcq", "prompt": "A woman with blood group AO and a man with blood group BO can have children with which blood groups?", "options": ["AB only", "A and B only", "A, B, AB and O", "O only"], "correctIndex": 2, "points": 10}, {"id": "q9", "type": "mcq", "prompt": "A sudden, permanent change in the base sequence of DNA is a…", "options": ["Meiosis", "Mutation", "Translation", "Codominance"], "correctIndex": 1, "points": 10}, {"id": "q10", "type": "mcq", "prompt": "Down syndrome is usually caused by…", "options": ["A virus infection", "A missing X chromosome", "A recessive allele on chromosome 7", "An extra copy of chromosome 21"], "correctIndex": 3, "points": 10}]$q$::jsonb, 'Academia', true, 'Senior Secondary School', 'Genetics'
where not exists (select 1 from public.tests where title = 'Genetics: Inheritance and Variation');

insert into public.tests (subject, title, description, difficulty, questions, created_by_name, published, category, topic)
select 'Chemistry', 'Organic Chemistry: Homologous Series', 'Alkanes, alkenes, alcohols and carboxylic acids: formulae, naming, reactions and tests.', 'medium'::test_difficulty,
       $q$[{"id": "q1", "type": "mcq", "prompt": "What is the general formula of the alkanes?", "options": ["CnH2n+2", "CnH2n", "CnH2n-2", "CnH2n+1OH"], "correctIndex": 0, "points": 10}, {"id": "q2", "type": "mcq", "prompt": "Which compound is the third member of the alkane series?", "options": ["Butane, C4H10", "Ethene, C2H4", "Propane, C3H8", "Methanol, CH3OH"], "correctIndex": 2, "points": 10}, {"id": "q3", "type": "mcq", "prompt": "Which reagent is used to test for a carbon–carbon double bond?", "options": ["Limewater, which turns milky", "Bromine water, which is decolourised", "Universal indicator, which turns red", "Silver nitrate, which forms a white precipitate"], "correctIndex": 1, "points": 10}, {"id": "q4", "type": "mcq", "prompt": "Ethene reacts with steam in the presence of a catalyst to form…", "options": ["Poly(ethene)", "Ethane", "Ethanoic acid", "Ethanol"], "correctIndex": 3, "points": 10}, {"id": "q5", "type": "mcq", "prompt": "The functional group of the alcohols is…", "options": ["–OH (hydroxyl)", "–COOH (carboxyl)", "C=C (double bond)", "–CHO (aldehyde)"], "correctIndex": 0, "points": 10}, {"id": "q6", "type": "mcq", "prompt": "Methane reacts with chlorine in sunlight. This is an example of…", "options": ["Polymerisation", "Addition", "Substitution", "Neutralisation"], "correctIndex": 2, "points": 10}, {"id": "q7", "type": "mcq", "prompt": "Ethanol is oxidised (e.g. by acidified potassium dichromate) to form…", "options": ["Ethene", "Ethanoic acid", "Ethyl ethanoate", "Methanol"], "correctIndex": 1, "points": 10}, {"id": "q8", "type": "mcq", "prompt": "An alcohol reacts with a carboxylic acid to form an ester and…", "options": ["Oxygen", "Hydrogen", "Carbon dioxide", "Water"], "correctIndex": 3, "points": 10}, {"id": "q9", "type": "mcq", "prompt": "Members of a homologous series have the same…", "options": ["General formula and functional group", "Molecular mass", "Boiling point", "Number of carbon atoms"], "correctIndex": 0, "points": 10}, {"id": "q10", "type": "mcq", "prompt": "Butane and 2-methylpropane both have the formula C4H10. They are…", "options": ["Isotopes", "Allotropes", "Structural isomers", "Polymers"], "correctIndex": 2, "points": 10}]$q$::jsonb, 'Academia', true, 'Senior Secondary School', 'Organic Chemistry'
where not exists (select 1 from public.tests where title = 'Organic Chemistry: Homologous Series');

insert into public.tests (subject, title, description, difficulty, questions, created_by_name, published, category, topic)
select 'Computer Science', 'Data Structures: Arrays, Stacks, Queues and Trees', 'How common data structures store and organise data, and when to use each.', 'medium'::test_difficulty,
       $q$[{"id": "q1", "type": "mcq", "prompt": "Which data structure follows Last In, First Out (LIFO)?", "options": ["Queue", "Stack", "Array", "Linked list"], "correctIndex": 1, "points": 10}, {"id": "q2", "type": "mcq", "prompt": "Which data structure follows First In, First Out (FIFO)?", "options": ["Hash table", "Stack", "Binary tree", "Queue"], "correctIndex": 3, "points": 10}, {"id": "q3", "type": "mcq", "prompt": "In a zero-indexed array A = [4, 9, 2, 7], what is A[2]?", "options": ["2", "9", "7", "4"], "correctIndex": 0, "points": 10}, {"id": "q4", "type": "mcq", "prompt": "Adding an item to the top of a stack is called…", "options": ["Enqueue", "Pop", "Push", "Peek"], "correctIndex": 2, "points": 10}, {"id": "q5", "type": "mcq", "prompt": "In a linked list, each node stores data and…", "options": ["The index of the last node", "A pointer to the next node", "A copy of the whole list", "The size of the list"], "correctIndex": 1, "points": 10}, {"id": "q6", "type": "mcq", "prompt": "The single node at the top of a tree, with no parent, is the…", "options": ["Edge", "Leaf", "Branch", "Root"], "correctIndex": 3, "points": 10}, {"id": "q7", "type": "mcq", "prompt": "In a binary search tree, values smaller than a node are stored in its…", "options": ["Left subtree", "Right subtree", "Parent node", "Root only"], "correctIndex": 0, "points": 10}, {"id": "q8", "type": "mcq", "prompt": "Binary search can only be used on a list that is…", "options": ["Empty", "Unsorted", "Sorted", "Stored as a stack"], "correctIndex": 2, "points": 10}, {"id": "q9", "type": "mcq", "prompt": "What is the main disadvantage of a static array compared with a linked list?", "options": ["It cannot store numbers", "Its size is fixed when it is created", "Elements cannot be accessed by index", "It uses no memory"], "correctIndex": 1, "points": 10}, {"id": "q10", "type": "mcq", "prompt": "Which structure is best for modelling people waiting to be served at a bank counter?", "options": ["Two-dimensional array", "Stack", "Tree", "Queue"], "correctIndex": 3, "points": 10}]$q$::jsonb, 'Academia', true, 'Senior Secondary School', 'Data Structures'
where not exists (select 1 from public.tests where title = 'Data Structures: Arrays, Stacks, Queues and Trees');

insert into public.tests (subject, title, description, difficulty, questions, created_by_name, published, category, topic)
select 'Economics', 'Microeconomics: Demand, Supply and Price', 'The laws of demand and supply, elasticity, equilibrium and market structures.', 'medium'::test_difficulty,
       $q$[{"id": "q1", "type": "mcq", "prompt": "The law of demand states that, other things being equal, when the price of a good rises…", "options": ["Quantity demanded falls", "Quantity demanded rises", "Supply falls", "Demand stays the same"], "correctIndex": 0, "points": 10}, {"id": "q2", "type": "mcq", "prompt": "The price at which quantity demanded equals quantity supplied is the…", "options": ["Reserve price", "Maximum price", "Equilibrium price", "Cost price"], "correctIndex": 2, "points": 10}, {"id": "q3", "type": "mcq", "prompt": "If the government sets a maximum price below equilibrium, the likely result is…", "options": ["A surplus", "A shortage", "No change in the market", "Higher profits for sellers"], "correctIndex": 1, "points": 10}, {"id": "q4", "type": "mcq", "prompt": "Goods used together, such as cars and petrol, are called…", "options": ["Giffen goods", "Substitute goods", "Inferior goods", "Complementary goods"], "correctIndex": 3, "points": 10}, {"id": "q5", "type": "mcq", "prompt": "A good whose demand falls as consumers' incomes rise is…", "options": ["An inferior good", "A normal good", "A luxury good", "A public good"], "correctIndex": 0, "points": 10}, {"id": "q6", "type": "mcq", "prompt": "If a 10% rise in price causes a 20% fall in quantity demanded, demand is…", "options": ["Unit elastic", "Price inelastic", "Price elastic (PED = 2)", "Perfectly inelastic"], "correctIndex": 2, "points": 10}, {"id": "q7", "type": "mcq", "prompt": "A good harvest of cocoa will most likely shift the supply curve…", "options": ["To the left, raising the price", "To the right, lowering the price", "Not at all", "Upwards, increasing demand"], "correctIndex": 1, "points": 10}, {"id": "q8", "type": "mcq", "prompt": "A market with a single seller and no close substitutes is a…", "options": ["Monopsony", "Perfect competition", "Oligopoly", "Monopoly"], "correctIndex": 3, "points": 10}, {"id": "q9", "type": "mcq", "prompt": "The extra satisfaction gained from consuming one more unit of a good is…", "options": ["Marginal utility", "Total utility", "Opportunity cost", "Consumer surplus"], "correctIndex": 0, "points": 10}, {"id": "q10", "type": "mcq", "prompt": "Opportunity cost is best defined as…", "options": ["The total cost of production", "The money price of a good", "The next best alternative forgone", "The cost of imported goods"], "correctIndex": 2, "points": 10}]$q$::jsonb, 'Academia', true, 'Senior Secondary School', 'Microeconomics'
where not exists (select 1 from public.tests where title = 'Microeconomics: Demand, Supply and Price');

insert into public.tests (subject, title, description, difficulty, questions, created_by_name, published, category, topic)
select 'English Language', 'Grammar: Parts of Speech, Tenses and Agreement', 'Identifying parts of speech, tenses, subject–verb agreement and common usage errors.', 'easy'::test_difficulty,
       $q$[{"id": "q1", "type": "mcq", "prompt": "Choose the correct sentence.", "options": ["Neither of the boys have finished their work.", "Neither of the boys has finished his work.", "Neither of the boy has finished his work.", "Neither of the boys have finished his work."], "correctIndex": 1, "points": 10}, {"id": "q2", "type": "mcq", "prompt": "In 'She sang beautifully', the word 'beautifully' is…", "options": ["A preposition", "An adjective", "A noun", "An adverb"], "correctIndex": 3, "points": 10}, {"id": "q3", "type": "mcq", "prompt": "Which word is a conjunction?", "options": ["Although", "Quickly", "Beneath", "Happiness"], "correctIndex": 0, "points": 10}, {"id": "q4", "type": "mcq", "prompt": "'By next June, I ___ in this school for five years.' Choose the correct form.", "options": ["have been", "will be", "will have been", "was"], "correctIndex": 2, "points": 10}, {"id": "q5", "type": "mcq", "prompt": "Choose the correctly punctuated sentence.", "options": ["Its raining, so the match has lost it's audience.", "It's raining, so the match has lost its audience.", "It's raining, so the match has lost it's audience.", "Its raining so the match has lost its audience."], "correctIndex": 1, "points": 10}, {"id": "q6", "type": "mcq", "prompt": "'The committee ___ reached a decision.' Choose the best verb.", "options": ["were", "have", "are", "has"], "correctIndex": 3, "points": 10}, {"id": "q7", "type": "mcq", "prompt": "Change to reported speech: He said, 'I am tired.'", "options": ["He said that he was tired.", "He said that I am tired.", "He said that he is tired yesterday.", "He says that he was tired."], "correctIndex": 0, "points": 10}, {"id": "q8", "type": "mcq", "prompt": "Which sentence is in the passive voice?", "options": ["Amina is writing a letter.", "Amina wrote the letter.", "The letter was written by Amina.", "Amina will write the letter."], "correctIndex": 2, "points": 10}, {"id": "q9", "type": "mcq", "prompt": "In 'The man who called you is my uncle', 'who called you' is…", "options": ["An adverbial clause", "A relative (adjective) clause", "A noun clause", "A main clause"], "correctIndex": 1, "points": 10}, {"id": "q10", "type": "mcq", "prompt": "Choose the correct word: 'The new policy will ___ every student.'", "options": ["effective", "effect", "affection", "affect"], "correctIndex": 3, "points": 10}]$q$::jsonb, 'Academia', true, 'Senior Secondary School', 'Grammar'
where not exists (select 1 from public.tests where title = 'Grammar: Parts of Speech, Tenses and Agreement');

insert into public.tests (subject, title, description, difficulty, questions, created_by_name, published, category, topic)
select 'Geography', 'Climate: Elements, Controls and Climate Types', 'Weather and climate, factors controlling climate, and the climates of Cameroon and Africa.', 'medium'::test_difficulty,
       $q$[{"id": "q1", "type": "mcq", "prompt": "The average weather conditions of a place over about 30 years is called its…", "options": ["Climate", "Weather", "Season", "Microclimate"], "correctIndex": 0, "points": 10}, {"id": "q2", "type": "mcq", "prompt": "Temperature generally decreases with altitude at a rate of about…", "options": ["20 °C per 1000 m", "1 °C per 1000 m", "6.5 °C per 1000 m", "0.5 °C per 100 km"], "correctIndex": 2, "points": 10}, {"id": "q3", "type": "mcq", "prompt": "Which instrument measures atmospheric pressure?", "options": ["Hygrometer", "Barometer", "Anemometer", "Thermometer"], "correctIndex": 1, "points": 10}, {"id": "q4", "type": "mcq", "prompt": "Rain formed when moist air is forced to rise over a mountain is…", "options": ["Acid rain", "Convectional rainfall", "Frontal rainfall", "Relief (orographic) rainfall"], "correctIndex": 3, "points": 10}, {"id": "q5", "type": "mcq", "prompt": "Debundscha, at the foot of Mount Cameroon, is one of the wettest places on Earth mainly because of…", "options": ["Moist south-west monsoon winds rising over the mountain", "Its distance from the sea", "The Harmattan wind", "Its high latitude"], "correctIndex": 0, "points": 10}, {"id": "q6", "type": "mcq", "prompt": "The dry, dusty north-east wind that blows from the Sahara across West Africa is the…", "options": ["Sirocco", "Monsoon", "Harmattan", "Föhn"], "correctIndex": 2, "points": 10}, {"id": "q7", "type": "mcq", "prompt": "Places near the equator, such as southern Cameroon, have…", "options": ["Cold winters and hot summers", "High temperatures and rainfall in most months", "Very little rainfall all year", "Snow in the dry season"], "correctIndex": 1, "points": 10}, {"id": "q8", "type": "mcq", "prompt": "Why are coastal areas cooler in summer and milder in winter than inland areas?", "options": ["Coastal winds are always cold", "Coastal areas are at higher altitude", "The sun shines less at the coast", "The sea heats up and cools down more slowly than land"], "correctIndex": 3, "points": 10}, {"id": "q9", "type": "mcq", "prompt": "The Inter-Tropical Convergence Zone (ITCZ) mainly brings…", "options": ["Rainfall as it migrates north and south", "Snow to the tropics", "Permanent drought", "Earthquakes"], "correctIndex": 0, "points": 10}, {"id": "q10", "type": "mcq", "prompt": "The Sahel zone of northern Cameroon has a climate that is…", "options": ["Mediterranean", "Equatorial with two rainy seasons", "Hot and semi-arid with a short rainy season", "Temperate maritime"], "correctIndex": 2, "points": 10}]$q$::jsonb, 'Academia', true, 'Senior Secondary School', 'Climate'
where not exists (select 1 from public.tests where title = 'Climate: Elements, Controls and Climate Types');

insert into public.tests (subject, title, description, difficulty, questions, created_by_name, published, category, topic)
select 'History', 'World War II: Causes, Course and Consequences', 'From the rise of fascism to the end of the war in 1945 and its effects on Africa.', 'medium'::test_difficulty,
       $q$[{"id": "q1", "type": "mcq", "prompt": "World War II began in Europe when Germany invaded which country in September 1939?", "options": ["France", "Poland", "Czechoslovakia", "Belgium"], "correctIndex": 1, "points": 10}, {"id": "q2", "type": "mcq", "prompt": "Which treaty, signed in 1919, was resented in Germany and is often seen as a cause of the war?", "options": ["The Treaty of Westphalia", "The Treaty of Rome", "The Treaty of Paris (1856)", "The Treaty of Versailles"], "correctIndex": 3, "points": 10}, {"id": "q3", "type": "mcq", "prompt": "The policy of giving in to Hitler's demands in the 1930s, as at Munich in 1938, is called…", "options": ["Appeasement", "Containment", "Isolationism", "Decolonisation"], "correctIndex": 0, "points": 10}, {"id": "q4", "type": "mcq", "prompt": "The United States entered the war after Japan attacked…", "options": ["London", "Hiroshima", "Pearl Harbor (December 1941)", "Moscow"], "correctIndex": 2, "points": 10}, {"id": "q5", "type": "mcq", "prompt": "The Allied landing in Normandy on 6 June 1944 is known as…", "options": ["Operation Barbarossa", "D-Day", "The Blitz", "Dunkirk"], "correctIndex": 1, "points": 10}, {"id": "q6", "type": "mcq", "prompt": "The war in Europe ended with Germany's surrender in…", "options": ["August 1946", "November 1918", "September 1939", "May 1945"], "correctIndex": 3, "points": 10}, {"id": "q7", "type": "mcq", "prompt": "Atomic bombs were dropped on which two Japanese cities in August 1945?", "options": ["Hiroshima and Nagasaki", "Tokyo and Osaka", "Kyoto and Kobe", "Nagoya and Yokohama"], "correctIndex": 0, "points": 10}, {"id": "q8", "type": "mcq", "prompt": "Africans from the British and French colonies, including Cameroon, served in the war as…", "options": ["Members of the German army", "Neutral observers only", "Soldiers and labourers for the Allied armies", "They did not take part at all"], "correctIndex": 2, "points": 10}, {"id": "q9", "type": "mcq", "prompt": "Which international organisation was founded in 1945 to maintain world peace?", "options": ["The League of Nations", "The United Nations", "The African Union", "NATO"], "correctIndex": 1, "points": 10}, {"id": "q10", "type": "mcq", "prompt": "One major consequence of the war for Africa was…", "options": ["The creation of the Berlin Conference", "The return of German rule over Cameroon", "The end of all trade with Europe", "The growth of nationalist movements demanding independence"], "correctIndex": 3, "points": 10}]$q$::jsonb, 'Academia', true, 'Senior Secondary School', 'World War 2'
where not exists (select 1 from public.tests where title = 'World War II: Causes, Course and Consequences');

insert into public.tests (subject, title, description, difficulty, questions, created_by_name, published, category, topic)
select 'Literature', 'Poetry: Figures of Speech and Poetic Devices', 'Recognising and explaining the devices poets use, with short illustrative lines.', 'easy'::test_difficulty,
       $q$[{"id": "q1", "type": "mcq", "prompt": "'Her smile was a ray of sunshine' is an example of…", "options": ["Metaphor", "Simile", "Personification", "Hyperbole"], "correctIndex": 0, "points": 10}, {"id": "q2", "type": "mcq", "prompt": "'He was as brave as a lion' uses a…", "options": ["Oxymoron", "Metaphor", "Simile", "Pun"], "correctIndex": 2, "points": 10}, {"id": "q3", "type": "mcq", "prompt": "'The wind whispered through the trees' is an example of…", "options": ["Alliteration", "Personification", "Irony", "Onomatopoeia"], "correctIndex": 1, "points": 10}, {"id": "q4", "type": "mcq", "prompt": "'Peter Piper picked a peck of pickled peppers' mainly uses…", "options": ["Euphemism", "Assonance", "Enjambment", "Alliteration"], "correctIndex": 3, "points": 10}, {"id": "q5", "type": "mcq", "prompt": "A poem of fourteen lines, often with a fixed rhyme scheme, is a…", "options": ["Sonnet", "Haiku", "Limerick", "Ballad"], "correctIndex": 0, "points": 10}, {"id": "q6", "type": "mcq", "prompt": "Words like 'buzz', 'crash' and 'sizzle', which imitate sounds, are examples of…", "options": ["Synecdoche", "Paradox", "Onomatopoeia", "Apostrophe"], "correctIndex": 2, "points": 10}, {"id": "q7", "type": "mcq", "prompt": "'I've told you a million times!' is an example of…", "options": ["Litotes", "Hyperbole", "Simile", "Metonymy"], "correctIndex": 1, "points": 10}, {"id": "q8", "type": "mcq", "prompt": "A group of lines forming a unit within a poem is called a…", "options": ["Chorus", "Refrain", "Couplet only", "Stanza"], "correctIndex": 3, "points": 10}, {"id": "q9", "type": "mcq", "prompt": "When a sentence runs on from one line of poetry to the next without a pause, this is…", "options": ["Enjambment", "Caesura", "Rhyme", "Assonance"], "correctIndex": 0, "points": 10}, {"id": "q10", "type": "mcq", "prompt": "'Bitter sweet' and 'deafening silence' are examples of…", "options": ["Anaphora", "Pathetic fallacy", "Oxymoron", "Rhetorical question"], "correctIndex": 2, "points": 10}]$q$::jsonb, 'Academia', true, 'Senior Secondary School', 'Poetry'
where not exists (select 1 from public.tests where title = 'Poetry: Figures of Speech and Poetic Devices');

insert into public.tests (subject, title, description, difficulty, questions, created_by_name, published, category, topic)
select 'Mathematics', 'Algebra: Equations, Factorisation and Indices', 'Solving linear and quadratic equations, simultaneous equations, factorising and laws of indices.', 'medium'::test_difficulty,
       $q$[{"id": "q1", "type": "mcq", "prompt": "Solve 3x − 7 = 11.", "options": ["x = 4/3", "x = 6", "x = 18", "x = −6"], "correctIndex": 1, "points": 10}, {"id": "q2", "type": "mcq", "prompt": "Factorise x² − 9.", "options": ["x(x − 9)", "(x − 9)(x + 1)", "(x − 3)²", "(x − 3)(x + 3)"], "correctIndex": 3, "points": 10}, {"id": "q3", "type": "mcq", "prompt": "Solve x² − 5x + 6 = 0.", "options": ["x = 2 or x = 3", "x = −2 or x = −3", "x = 1 or x = 6", "x = 5 or x = 6"], "correctIndex": 0, "points": 10}, {"id": "q4", "type": "mcq", "prompt": "Simplify 2³ × 2⁴.", "options": ["4⁷", "2¹² = 4096", "2⁷ = 128", "2¹"], "correctIndex": 2, "points": 10}, {"id": "q5", "type": "mcq", "prompt": "Solve the simultaneous equations x + y = 10 and x − y = 4.", "options": ["x = 3, y = 7", "x = 7, y = 3", "x = 6, y = 4", "x = 5, y = 5"], "correctIndex": 1, "points": 10}, {"id": "q6", "type": "mcq", "prompt": "Expand (2x + 3)(x − 1).", "options": ["2x² − x + 3", "2x² − 3", "2x² + 5x − 3", "2x² + x − 3"], "correctIndex": 3, "points": 10}, {"id": "q7", "type": "mcq", "prompt": "What is the value of 9^(1/2)?", "options": ["3", "4.5", "81", "1/3"], "correctIndex": 0, "points": 10}, {"id": "q8", "type": "mcq", "prompt": "If f(x) = 2x² − 1, find f(−2).", "options": ["9", "−9", "7", "−7"], "correctIndex": 2, "points": 10}, {"id": "q9", "type": "mcq", "prompt": "Make r the subject of A = πr².", "options": ["r = A/(2π)", "r = √(A/π)", "r = √A/π", "r = A²/π"], "correctIndex": 1, "points": 10}, {"id": "q10", "type": "mcq", "prompt": "The sum of the roots of x² − 7x + 10 = 0 is…", "options": ["3", "10", "−7", "7"], "correctIndex": 3, "points": 10}]$q$::jsonb, 'Academia', true, 'Senior Secondary School', 'Algebra'
where not exists (select 1 from public.tests where title = 'Algebra: Equations, Factorisation and Indices');

insert into public.tests (subject, title, description, difficulty, questions, created_by_name, published, category, topic)
select 'Physics', 'Mechanics: Motion, Forces and Energy', 'Speed, velocity and acceleration, Newton''s laws, momentum, work, energy and power (take g = 10 m/s²).', 'medium'::test_difficulty,
       $q$[{"id": "q1", "type": "mcq", "prompt": "A car travels 150 m in 10 s at constant speed. What is its speed?", "options": ["15 m/s", "1.5 m/s", "1500 m/s", "160 m/s"], "correctIndex": 0, "points": 10}, {"id": "q2", "type": "mcq", "prompt": "A body accelerates uniformly from rest to 20 m/s in 4 s. Its acceleration is…", "options": ["0.2 m/s²", "80 m/s²", "5 m/s²", "24 m/s²"], "correctIndex": 2, "points": 10}, {"id": "q3", "type": "mcq", "prompt": "Newton's first law states that a body remains at rest or in uniform motion unless…", "options": ["Its mass changes", "Acted on by a resultant (unbalanced) force", "It is in a vacuum", "Its speed is zero"], "correctIndex": 1, "points": 10}, {"id": "q4", "type": "mcq", "prompt": "What resultant force is needed to give a 2 kg mass an acceleration of 3 m/s²?", "options": ["0.67 N", "1.5 N", "5 N", "6 N"], "correctIndex": 3, "points": 10}, {"id": "q5", "type": "mcq", "prompt": "The weight of a 5 kg mass on Earth is…", "options": ["50 N", "5 N", "0.5 N", "500 N"], "correctIndex": 0, "points": 10}, {"id": "q6", "type": "mcq", "prompt": "Momentum is calculated as…", "options": ["Mass × acceleration", "Force × time²", "Mass × velocity", "Velocity ÷ mass"], "correctIndex": 2, "points": 10}, {"id": "q7", "type": "mcq", "prompt": "A 2 kg stone is lifted 3 m. The gain in gravitational potential energy is…", "options": ["6 J", "60 J", "30 J", "600 J"], "correctIndex": 1, "points": 10}, {"id": "q8", "type": "mcq", "prompt": "The kinetic energy of a 4 kg trolley moving at 3 m/s is…", "options": ["6 J", "12 J", "36 J", "18 J"], "correctIndex": 3, "points": 10}, {"id": "q9", "type": "mcq", "prompt": "A machine does 1200 J of work in 4 s. Its power is…", "options": ["300 W", "4800 W", "1204 W", "0.003 W"], "correctIndex": 0, "points": 10}, {"id": "q10", "type": "mcq", "prompt": "'For every action there is an equal and opposite reaction' is Newton's…", "options": ["Second law", "First law", "Third law", "Law of gravitation"], "correctIndex": 2, "points": 10}]$q$::jsonb, 'Academia', true, 'Senior Secondary School', 'Mechanics'
where not exists (select 1 from public.tests where title = 'Mechanics: Motion, Forces and Energy');

commit;

-- ═══════════════════════════════ UNDO ════════════════════════════════════
-- update public.tests   set published = true where id in (select row_id from public.content_cleanup_log where run_label = '2026-10 placeholder cleanup' and table_name = 'tests');
-- update public.courses set published = true where id in (select row_id from public.content_cleanup_log where run_label = '2026-10 placeholder cleanup' and table_name = 'courses');
