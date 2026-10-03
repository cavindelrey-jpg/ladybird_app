// lib/data/daily_learning_courses.dart
// Daily Challenge curriculum: 3 courses x 30 daily lessons, each with three
// teaching points and two questions (correct answers spread evenly across
// positions A-D).
//
// Replaced 2026-10-02: every one of the previous 180 lessons was a generated
// placeholder ("This lesson covers fundamental principles.") with the same
// quiz "What day of the course is this?" whose options listed "Day 1"
// twice and marked only the second one correct. Lesson ids keep the
// '<course>_<day>' scheme so stored progress still lines up.

import '../models/daily_learning.dart';

const DailyLearningCourse etymologyCourse = DailyLearningCourse(
  id: 'etymology',
  title: 'Etymology',
  description: 'Master the Greek and Latin roots behind everyday English words, one root a day.',
  lessons: [
    DailyLearningLesson(
      id: 'etymology_1',
      title: 'Day 1: Roots: what words are made of',
      teachingPoints: [
        'Etymology is the study of where words come from and how their meanings changed over time.',
        'Many English words are built from Greek and Latin parts: a root carries the core meaning, prefixes and suffixes adjust it.',
        'If you know the root, you can often work out a word you have never seen before.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'What does etymology study?',
          options: ['The spelling rules of English', 'How insects are classified', 'The origin and history of words', 'The sounds of speech'],
          correctIndex: 2,
          explanation: 'Etymology traces where words come from and how their meanings developed.',
        ),
        DailyLearningQuestion(
          prompt: 'In the word \'biology\', which part carries the core meaning \'life\'?',
          options: ['bio', 'bi-', '-logy', '-y'],
          correctIndex: 0,
          explanation: '\'bio\' (Greek bios) means life; \'-logy\' means study of.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_2',
      title: 'Day 2: bio — life',
      teachingPoints: [
        'Greek \'bios\' means life.',
        'Biology is the study of life; a biography is the written story of a person\'s life.',
        'Antibiotics act against living bacteria; biodiversity is the variety of life in a place.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'A biography is…',
          options: ['A study of plants', 'A type of graph', 'A medicine', 'The written account of someone\'s life'],
          correctIndex: 3,
          explanation: 'bio (life) + graph (write): a written life story.',
        ),
        DailyLearningQuestion(
          prompt: 'Biodegradable packaging is broken down by…',
          options: ['Sunlight only', 'Living organisms', 'Fire', 'Magnets'],
          correctIndex: 1,
          explanation: 'Bio- refers to life: biodegradable means living organisms (bacteria, fungi) can break it down.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_3',
      title: 'Day 3: graph / gram — write, draw',
      teachingPoints: [
        'Greek \'graphein\' means to write or draw.',
        'A photograph is \'drawn with light\'; a telegram is a message \'written from far away\'.',
        'Autograph = self + write: your own signature.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Which word means \'your own written signature\'?',
          options: ['Paragraph', 'Diagram', 'Autograph', 'Graphite'],
          correctIndex: 2,
          explanation: 'auto (self) + graph (write).',
        ),
        DailyLearningQuestion(
          prompt: 'Graphite is used in pencils. Why the name?',
          options: ['It is used for writing', 'It comes from Greece', 'It is heavy', 'It is a graph'],
          correctIndex: 0,
          explanation: 'Graphite was named from \'graphein\' because it is used to write.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_4',
      title: 'Day 4: tele — far',
      teachingPoints: [
        'Greek \'tele\' means far or at a distance.',
        'Telephone = far + sound; television = far + seeing; telescope = far + look.',
        'Telecommunication means communicating over a distance.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'A telescope lets you…',
          options: ['Hear distant sounds', 'Measure heat', 'Write quickly', 'See distant things'],
          correctIndex: 3,
          explanation: 'tele (far) + scope (look at).',
        ),
        DailyLearningQuestion(
          prompt: 'Which word literally means \'sound from far away\'?',
          options: ['Megaphone', 'Telephone', 'Microphone', 'Phonics'],
          correctIndex: 1,
          explanation: 'tele (far) + phone (sound).',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_5',
      title: 'Day 5: phon — sound',
      teachingPoints: [
        'Greek \'phone\' means sound or voice.',
        'Phonics teaches the sounds letters make; a symphony is sounds played together.',
        'A microphone picks up small sounds; a megaphone makes your voice big.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: '\'Symphony\' means sounds that are…',
          options: ['Loud', 'Recorded', 'Played together', 'Very old'],
          correctIndex: 2,
          explanation: 'sym (together) + phon (sound).',
        ),
        DailyLearningQuestion(
          prompt: 'A megaphone…',
          options: ['Makes your voice louder', 'Makes small sounds', 'Records sounds', 'Blocks sound'],
          correctIndex: 0,
          explanation: 'mega (large) + phone (sound): it makes a sound big.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_6',
      title: 'Day 6: photo — light',
      teachingPoints: [
        'Greek \'phos/photos\' means light.',
        'Photosynthesis is how plants build food using light.',
        'A photon is a particle of light; photosensitive means reacting to light.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'In photosynthesis, plants use ___ to make food.',
          options: ['Heat', 'Wind', 'Sound', 'Light'],
          correctIndex: 3,
          explanation: 'photo (light) + synthesis (putting together).',
        ),
        DailyLearningQuestion(
          prompt: 'Photosensitive skin reacts to…',
          options: ['Water', 'Light', 'Cold', 'Noise'],
          correctIndex: 1,
          explanation: 'photo = light.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_7',
      title: 'Day 7: geo — earth',
      teachingPoints: [
        'Greek \'ge\' means earth.',
        'Geography describes the earth; geology studies its rocks.',
        'Geometry began as \'earth measuring\' — surveying land.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Geology is the study of…',
          options: ['Stars', 'Living things', 'Rocks and the earth', 'Languages'],
          correctIndex: 2,
          explanation: 'geo (earth) + logy (study).',
        ),
        DailyLearningQuestion(
          prompt: 'Geometry originally meant…',
          options: ['Measuring the earth', 'Drawing circles', 'Counting money', 'Studying maps'],
          correctIndex: 0,
          explanation: 'geo (earth) + metron (measure): ancient surveyors measured land.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_8',
      title: 'Day 8: logy / log — study, word',
      teachingPoints: [
        'Greek \'logos\' means word, reason or study.',
        '-logy names a field of study: zoology (animals), psychology (the mind).',
        'A dialogue is a conversation; a monologue is one person speaking.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Zoology is the study of…',
          options: ['Plants', 'Weather', 'The mind', 'Animals'],
          correctIndex: 3,
          explanation: 'zoo (animal) + logy (study).',
        ),
        DailyLearningQuestion(
          prompt: 'A monologue is…',
          options: ['A talk between two people', 'A long speech by one person', 'A list of words', 'A study of monkeys'],
          correctIndex: 1,
          explanation: 'mono (one) + logue (speech).',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_9',
      title: 'Day 9: chron — time',
      teachingPoints: [
        'Greek \'chronos\' means time.',
        'A chronometer measures time; chronological means in time order.',
        'A chronic illness lasts a long time; synchronise = make happen at the same time.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Events listed in chronological order are listed…',
          options: ['By importance', 'Alphabetically', 'In the order they happened', 'By size'],
          correctIndex: 2,
          explanation: 'chron (time): in time order.',
        ),
        DailyLearningQuestion(
          prompt: 'A chronic cough is one that…',
          options: ['Lasts a long time', 'Is very loud', 'Is caused by cold', 'Is contagious'],
          correctIndex: 0,
          explanation: 'Chronic = lasting a long time.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_10',
      title: 'Day 10: micro & macro — small & large',
      teachingPoints: [
        'Greek \'mikros\' means small; \'makros\' means large or long.',
        'A microscope looks at small things; microbes are tiny living organisms.',
        'Macroeconomics studies a whole economy; microeconomics studies single households and firms.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'A microbe is…',
          options: ['A huge animal', 'A unit of time', 'A type of rock', 'A tiny living organism'],
          correctIndex: 3,
          explanation: 'micro (small) + bios (life).',
        ),
        DailyLearningQuestion(
          prompt: 'Macroeconomics looks at…',
          options: ['One shop', 'A whole country\'s economy', 'A single family', 'Coins'],
          correctIndex: 1,
          explanation: 'macro = large: the economy as a whole.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_11',
      title: 'Day 11: scope — look at',
      teachingPoints: [
        'Greek \'skopein\' means to look at or examine.',
        'A stethoscope lets a doctor examine the chest by listening; a periscope looks around obstacles.',
        'A horoscope claims to \'look at the hour\' of your birth.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'A periscope is used to…',
          options: ['Listen to the heart', 'Measure temperature', 'Look around or over obstacles', 'Write letters'],
          correctIndex: 2,
          explanation: 'peri (around) + scope (look).',
        ),
        DailyLearningQuestion(
          prompt: 'Which instrument lets you look at very small things?',
          options: ['Microscope', 'Telescope', 'Kaleidoscope', 'Stethoscope'],
          correctIndex: 0,
          explanation: 'micro (small) + scope (look).',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_12',
      title: 'Day 12: auto — self',
      teachingPoints: [
        'Greek \'autos\' means self.',
        'An automobile moves by itself; automatic means working by itself.',
        'Autonomy is self-rule; an autobiography is your own life story written by you.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'An autobiography is written by…',
          options: ['A journalist', 'A historian', 'A teacher', 'The person it is about'],
          correctIndex: 3,
          explanation: 'auto (self) + bio (life) + graph (write).',
        ),
        DailyLearningQuestion(
          prompt: 'An autonomous region…',
          options: ['Has no people', 'Governs itself', 'Is very cold', 'Moves by itself'],
          correctIndex: 1,
          explanation: 'auto (self) + nomos (law): self-governing.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_13',
      title: 'Day 13: hydr — water',
      teachingPoints: [
        'Greek \'hydor\' means water.',
        'Hydroelectric power is made from moving water — Cameroon\'s Edea and Song Loulou dams use it.',
        'To dehydrate is to lose water; a fire hydrant supplies water.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Dehydration means the body has lost…',
          options: ['Salt', 'Blood', 'Water', 'Heat'],
          correctIndex: 2,
          explanation: 'de (remove) + hydr (water).',
        ),
        DailyLearningQuestion(
          prompt: 'Hydroelectric power is generated from…',
          options: ['Moving water', 'Wind', 'Sunlight', 'Coal'],
          correctIndex: 0,
          explanation: 'hydro (water) + electric.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_14',
      title: 'Day 14: therm — heat',
      teachingPoints: [
        'Greek \'therme\' means heat.',
        'A thermometer measures heat (temperature); a thermos keeps drinks hot or cold.',
        'Geothermal energy comes from heat inside the earth.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Geothermal energy comes from…',
          options: ['The sun', 'Wind', 'Ocean waves', 'Heat inside the earth'],
          correctIndex: 3,
          explanation: 'geo (earth) + therm (heat).',
        ),
        DailyLearningQuestion(
          prompt: 'A thermostat controls…',
          options: ['Light', 'Temperature', 'Sound', 'Speed'],
          correctIndex: 1,
          explanation: 'thermo (heat) + stat (stand/keep steady).',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_15',
      title: 'Day 15: aqua — water (Latin)',
      teachingPoints: [
        'Latin \'aqua\' means water (compare Greek \'hydr\').',
        'An aquarium holds water animals; an aqueduct carries water.',
        'Aquatic animals live in water.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'An aqueduct is built to…',
          options: ['Measure rain', 'Store grain', 'Carry water', 'Block rivers'],
          correctIndex: 2,
          explanation: 'aqua (water) + duct (lead).',
        ),
        DailyLearningQuestion(
          prompt: 'Which word is from LATIN for water?',
          options: ['Aquatic', 'Hydrant', 'Dehydrate', 'Hydraulic'],
          correctIndex: 0,
          explanation: 'aqua is Latin; hydr is Greek.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_16',
      title: 'Day 16: port — carry',
      teachingPoints: [
        'Latin \'portare\' means to carry.',
        'To transport is to carry across; a porter carries luggage.',
        'Portable means easy to carry; to export is to carry goods out of a country.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Cameroon exports cocoa. Export means to…',
          options: ['Grow it', 'Store it', 'Eat it', 'Carry it out of the country'],
          correctIndex: 3,
          explanation: 'ex (out) + port (carry).',
        ),
        DailyLearningQuestion(
          prompt: 'A portable radio is one that…',
          options: ['Is very loud', 'Can be carried', 'Works in ports', 'Is very old'],
          correctIndex: 1,
          explanation: 'port (carry) + able.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_17',
      title: 'Day 17: dict — say, speak',
      teachingPoints: [
        'Latin \'dicere/dictum\' means to say.',
        'A dictionary lists what words say (mean); to predict is to say before.',
        'A verdict is a \'true saying\' by a court; to contradict is to speak against.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'To predict means to…',
          options: ['Write down', 'Say again', 'Say before it happens', 'Speak quietly'],
          correctIndex: 2,
          explanation: 'pre (before) + dict (say).',
        ),
        DailyLearningQuestion(
          prompt: 'If you contradict someone you…',
          options: ['Speak against what they said', 'Agree with them', 'Copy them', 'Ignore them'],
          correctIndex: 0,
          explanation: 'contra (against) + dict (say).',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_18',
      title: 'Day 18: spect — look',
      teachingPoints: [
        'Latin \'specere/spectare\' means to look.',
        'Spectators look at a match; to inspect is to look into something carefully.',
        'Respect originally meant to \'look back at\' someone with regard.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'A spectator at a football match…',
          options: ['Plays', 'Sells tickets', 'Referees', 'Watches'],
          correctIndex: 3,
          explanation: 'spect (look).',
        ),
        DailyLearningQuestion(
          prompt: 'Which word means \'to look into something carefully\'?',
          options: ['Expect', 'Inspect', 'Suspect', 'Spectacle'],
          correctIndex: 1,
          explanation: 'in (into) + spect (look).',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_19',
      title: 'Day 19: struct — build',
      teachingPoints: [
        'Latin \'struere/structum\' means to build.',
        'A structure is something built; to construct is to build together.',
        'To destroy (de-struct) is to un-build; instruction \'builds in\' knowledge.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'To reconstruct a bridge is to…',
          options: ['Paint it', 'Close it', 'Build it again', 'Cross it'],
          correctIndex: 2,
          explanation: 're (again) + con (together) + struct (build).',
        ),
        DailyLearningQuestion(
          prompt: 'Destruction is the opposite of…',
          options: ['Construction', 'Instruction', 'Obstruction', 'Structure'],
          correctIndex: 0,
          explanation: 'de (undo) vs con (together): destroying vs building.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_20',
      title: 'Day 20: rupt — break',
      teachingPoints: [
        'Latin \'rumpere/ruptum\' means to break.',
        'A volcano erupts — lava breaks out, as on Mount Cameroon, an active volcano.',
        'To interrupt is to break into a conversation; a bankrupt business is \'broken\'.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'When a volcano erupts, lava…',
          options: ['Freezes', 'Turns to water', 'Disappears', 'Breaks out'],
          correctIndex: 3,
          explanation: 'e (out) + rupt (break).',
        ),
        DailyLearningQuestion(
          prompt: 'Interrupting a speaker means…',
          options: ['Clapping for them', 'Breaking into their speech', 'Agreeing with them', 'Recording them'],
          correctIndex: 1,
          explanation: 'inter (between) + rupt (break).',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_21',
      title: 'Day 21: scrib / script — write',
      teachingPoints: [
        'Latin \'scribere/scriptum\' means to write.',
        'To describe is to write about; a manuscript is written by hand (manu = hand).',
        'To subscribe is to \'write under\' — originally signing your name at the bottom.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'A manuscript is a document written…',
          options: ['By machine', 'In code', 'By hand', 'In the future'],
          correctIndex: 2,
          explanation: 'manu (hand) + script (written).',
        ),
        DailyLearningQuestion(
          prompt: 'Which root means the same as Greek \'graph\'?',
          options: ['scrib/script', 'spect', 'port', 'rupt'],
          correctIndex: 0,
          explanation: 'Both mean to write: scribere (Latin), graphein (Greek).',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_22',
      title: 'Day 22: ject — throw',
      teachingPoints: [
        'Latin \'iacere/iectum\' means to throw.',
        'To reject is to throw back; a projectile is thrown forward.',
        'An injection \'throws in\' medicine; to eject is to throw out.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'A projector \'throws\' an image…',
          options: ['Backwards', 'Away', 'Into a box', 'Forward onto a screen'],
          correctIndex: 3,
          explanation: 'pro (forward) + ject (throw).',
        ),
        DailyLearningQuestion(
          prompt: 'If your application is rejected, it is…',
          options: ['Accepted', 'Thrown back', 'Delayed', 'Copied'],
          correctIndex: 1,
          explanation: 're (back) + ject (throw).',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_23',
      title: 'Day 23: duc / duct — lead',
      teachingPoints: [
        'Latin \'ducere/ductum\' means to lead.',
        'To educate is to lead out a person\'s abilities; to induce is to lead into.',
        'A conductor leads an orchestra — or leads electricity through a wire.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'A copper wire is a good conductor because it…',
          options: ['Blocks electricity', 'Stores electricity', 'Leads electricity through it', 'Makes electricity'],
          correctIndex: 2,
          explanation: 'con (together/with) + duct (lead).',
        ),
        DailyLearningQuestion(
          prompt: 'To reduce the price is to…',
          options: ['Lead it back down', 'Raise it', 'Print it', 'Hide it'],
          correctIndex: 0,
          explanation: 're (back) + duce (lead).',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_24',
      title: 'Day 24: vid / vis — see',
      teachingPoints: [
        'Latin \'videre/visum\' means to see.',
        'Vision is the ability to see; evidence is what makes something seen (evident).',
        'To supervise is to oversee; invisible means cannot be seen.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Invisible ink is ink that…',
          options: ['Smells', 'Glows', 'Is very dark', 'Cannot be seen'],
          correctIndex: 3,
          explanation: 'in (not) + vis (see) + ible (able).',
        ),
        DailyLearningQuestion(
          prompt: 'A supervisor…',
          options: ['Has super powers', 'Oversees others\' work', 'Reads books', 'Sells videos'],
          correctIndex: 1,
          explanation: 'super (over) + vis (see).',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_25',
      title: 'Day 25: aud — hear',
      teachingPoints: [
        'Latin \'audire\' means to hear.',
        'An audience hears a performance; audible means loud enough to be heard.',
        'An audition is a hearing — you perform so judges can hear you.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'An inaudible whisper is one that…',
          options: ['Is very loud', 'Is recorded', 'Cannot be heard', 'Is in another language'],
          correctIndex: 2,
          explanation: 'in (not) + aud (hear) + ible.',
        ),
        DailyLearningQuestion(
          prompt: 'Which word is about hearing?',
          options: ['Auditorium', 'Autograph', 'Aquarium', 'Aqueduct'],
          correctIndex: 0,
          explanation: 'aud (hear) + -torium (place): a place for listening.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_26',
      title: 'Day 26: mit / miss — send',
      teachingPoints: [
        'Latin \'mittere/missum\' means to send.',
        'A missile is sent through the air; to transmit is to send across.',
        'To submit homework is to send it in; a mission is a sending on a task.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'To transmit a signal is to…',
          options: ['Block it', 'Store it', 'Receive it', 'Send it across'],
          correctIndex: 3,
          explanation: 'trans (across) + mit (send).',
        ),
        DailyLearningQuestion(
          prompt: 'If you are dismissed from class you are…',
          options: ['Praised', 'Sent away', 'Promoted', 'Tested'],
          correctIndex: 1,
          explanation: 'dis (away) + miss (send).',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_27',
      title: 'Day 27: cred — believe',
      teachingPoints: [
        'Latin \'credere\' means to believe or trust.',
        'Credible means believable; incredible means hard to believe.',
        'Credit is trust that you will pay later; a creed is a statement of belief.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'A credible witness is one who is…',
          options: ['Young', 'Famous', 'Believable', 'Silent'],
          correctIndex: 2,
          explanation: 'cred (believe) + ible.',
        ),
        DailyLearningQuestion(
          prompt: 'Buying on credit relies on…',
          options: ['Trust that you will pay', 'Cash', 'Barter', 'A discount'],
          correctIndex: 0,
          explanation: 'credit comes from credere, to trust.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_28',
      title: 'Day 28: terr — earth, land',
      teachingPoints: [
        'Latin \'terra\' means earth or land (compare Greek \'geo\').',
        'Territory is an area of land; terrain is the type of ground.',
        'The Mediterranean is the sea \'in the middle of the lands\' (medi + terra).',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Mountainous terrain describes…',
          options: ['The weather', 'The language', 'The population', 'The type of land'],
          correctIndex: 3,
          explanation: 'terra = land.',
        ),
        DailyLearningQuestion(
          prompt: 'Which root, like \'geo\', refers to the earth?',
          options: ['aqua', 'terr', 'therm', 'port'],
          correctIndex: 1,
          explanation: 'terra (Latin) ≈ geo (Greek).',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_29',
      title: 'Day 29: bene & mal — good & bad',
      teachingPoints: [
        'Latin \'bene\' means well/good; \'male/mal\' means bad/badly.',
        'A benefit does good; a benefactor is someone who does good for others.',
        'Malnutrition is bad nourishment; a malfunction is a bad (faulty) working.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Malnutrition means…',
          options: ['Too much food', 'Good diet', 'Poor, inadequate nourishment', 'Vitamins'],
          correctIndex: 2,
          explanation: 'mal (bad) + nutrition.',
        ),
        DailyLearningQuestion(
          prompt: 'A benefactor is someone who…',
          options: ['Does good for others', 'Breaks laws', 'Studies roots', 'Builds roads'],
          correctIndex: 0,
          explanation: 'bene (good) + factor (doer).',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'etymology_30',
      title: 'Day 30: Putting roots together',
      teachingPoints: [
        'Most long words combine several roots: \'telephotography\' = far + light + writing.',
        'Break a new word into prefix + root + suffix, then rebuild the meaning.',
        'Check your guess against the sentence it appears in — context confirms the meaning.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Using roots, \'hydrology\' is most likely the study of…',
          options: ['Heat', 'Time', 'Life', 'Water'],
          correctIndex: 3,
          explanation: 'hydr (water) + logy (study).',
        ),
        DailyLearningQuestion(
          prompt: '\'Chronograph\' is most likely a device that…',
          options: ['Measures light', 'Records time', 'Carries water', 'Builds roads'],
          correctIndex: 1,
          explanation: 'chron (time) + graph (write/record).',
        ),
      ],
    ),
  ],
);

const DailyLearningCourse fallaciesCourse = DailyLearningCourse(
  id: 'logical_fallacies',
  title: 'Logical Fallacies',
  description: 'Learn to spot and answer flawed arguments in debates, adverts and essays.',
  lessons: [
    DailyLearningLesson(
      id: 'logical_fallacies_1',
      title: 'Day 1: What is a fallacy?',
      teachingPoints: [
        'A fallacy is an error in reasoning that makes an argument weak, even if it sounds convincing.',
        'A fallacious argument can still have a true conclusion — the problem is how it gets there.',
        'Spotting fallacies helps you judge debates, adverts and essays — and write stronger arguments yourself.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'A fallacy is…',
          options: ['A false fact', 'A rude remark', 'A flaw in reasoning', 'A long argument'],
          correctIndex: 2,
          explanation: 'A fallacy is about the reasoning, not just whether a claim is true.',
        ),
        DailyLearningQuestion(
          prompt: 'Can an argument with a fallacy reach a true conclusion?',
          options: ['Yes, by luck — but the reasoning doesn\'t support it', 'Never', 'Only in mathematics', 'Only if it is short'],
          correctIndex: 0,
          explanation: 'The conclusion may happen to be true; the fallacy is that the reasons given don\'t prove it.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_2',
      title: 'Day 2: Ad hominem — attacking the person',
      teachingPoints: [
        'Ad hominem means \'to the person\': attacking the speaker instead of their argument.',
        '\'Don\'t listen to her idea about the school garden — she failed Biology.\' The idea isn\'t examined at all.',
        'A person\'s character is relevant only when the argument depends on trusting them as a witness.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: '\'You can\'t trust his point about road safety; he\'s from the north.\' This is…',
          options: ['Straw man', 'Bandwagon', 'Slippery slope', 'Ad hominem'],
          correctIndex: 3,
          explanation: 'It attacks who he is instead of what he said.',
        ),
        DailyLearningQuestion(
          prompt: 'What should you respond to instead?',
          options: ['The person\'s background', 'The evidence and reasoning', 'Their clothes', 'Their popularity'],
          correctIndex: 1,
          explanation: 'Judge the argument on its evidence and logic.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_3',
      title: 'Day 3: Straw man',
      teachingPoints: [
        'A straw man misrepresents someone\'s argument as weaker or more extreme, then attacks that version.',
        'A: \'We should have less homework on weekends.\' B: \'So you want students to never study!\'',
        'Fix: restate the other side\'s view fairly before you disagree with it.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Which reply is a straw man of \'Phones should be off during lessons\'?',
          options: ['\'Phones distract many students\'', '\'Some lessons use phones for research\'', '\'So you want to ban all technology forever?\'', '\'We could allow phones for calculators only\''],
          correctIndex: 2,
          explanation: 'It exaggerates the original claim into something easier to attack.',
        ),
        DailyLearningQuestion(
          prompt: 'The best defence against a straw man is to…',
          options: ['Restate the real argument accurately', 'Shout louder', 'Change the subject', 'Agree immediately'],
          correctIndex: 0,
          explanation: 'Show what was actually claimed.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_4',
      title: 'Day 4: False dilemma',
      teachingPoints: [
        'A false dilemma presents only two options when more exist.',
        '\'Either you support every rule the prefect makes, or you\'re against discipline.\'',
        'Ask: are there other choices, a middle ground, or combinations?',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: '\'You are either with us or against us\' is often a…',
          options: ['Fair summary', 'Red herring', 'Circular argument', 'False dilemma'],
          correctIndex: 3,
          explanation: 'There may be neutral or partial positions.',
        ),
        DailyLearningQuestion(
          prompt: '\'Either we cancel sports day or exam results will fall.\' What is missing?',
          options: ['A citation', 'Other options, e.g. a shorter sports day', 'A rhyme', 'Nothing'],
          correctIndex: 1,
          explanation: 'It ignores alternatives between the two extremes.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_5',
      title: 'Day 5: Slippery slope',
      teachingPoints: [
        'A slippery slope claims one small step will inevitably lead to a chain of extreme results — without evidence for each link.',
        '\'If we let Form 1 use the library at lunch, soon nobody will go to class at all.\'',
        'Each step in a chain needs its own evidence; \'could\' is not \'will\'.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'What makes a slippery-slope argument weak?',
          options: ['It is about slopes', 'It uses numbers', 'It assumes each step will happen without evidence', 'It is too short'],
          correctIndex: 2,
          explanation: 'The chain of consequences is asserted, not shown.',
        ),
        DailyLearningQuestion(
          prompt: 'Which is a slippery slope?',
          options: ['\'If you miss one class you\'ll drop out and end up with nothing.\'', '\'Eating sweets daily may cause cavities.\'', '\'Rain is forecast, so bring an umbrella.\'', '\'Practice improves skill.\''],
          correctIndex: 0,
          explanation: 'It jumps from one missed class to an extreme outcome.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_6',
      title: 'Day 6: Appeal to authority',
      teachingPoints: [
        'Citing an expert is fine when they are an expert in that field and experts generally agree.',
        'It becomes a fallacy when the \'authority\' is irrelevant: \'A famous footballer says this herbal cure works.\'',
        'Ask: is this person an expert on THIS question, and what is the evidence?',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Which is a fallacious appeal to authority?',
          options: ['A doctor explaining a vaccine trial', 'A teacher explaining grammar', 'A geologist describing volcanoes', 'A singer claiming a medicine cures malaria'],
          correctIndex: 3,
          explanation: 'The singer has no expertise in medicine.',
        ),
        DailyLearningQuestion(
          prompt: 'Expert opinion is strongest when…',
          options: ['The expert is famous', 'Experts in that field broadly agree, backed by evidence', 'It is on social media', 'It is repeated often'],
          correctIndex: 1,
          explanation: 'Relevant expertise plus evidence and consensus.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_7',
      title: 'Day 7: Bandwagon (appeal to popularity)',
      teachingPoints: [
        'The bandwagon fallacy says something is true or good because many people believe or do it.',
        '\'Everyone is sharing this news, so it must be true.\'',
        'Popularity is not proof — millions once believed the sun went around the earth.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: '\'Most of my class thinks the test was unfair, so it was.\' This is…',
          options: ['Post hoc', 'Ad hominem', 'Bandwagon', 'Straw man'],
          correctIndex: 2,
          explanation: 'Many people believing it does not make it true.',
        ),
        DailyLearningQuestion(
          prompt: 'Why is a viral message not automatically reliable?',
          options: ['Because popularity doesn\'t prove accuracy', 'Because it is short', 'Because it uses images', 'It always is reliable'],
          correctIndex: 0,
          explanation: 'Check the source and evidence, not the number of shares.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_8',
      title: 'Day 8: Circular reasoning',
      teachingPoints: [
        'Circular reasoning (begging the question) uses the conclusion as one of its own reasons.',
        '\'This book is the best because it is better than all other books.\'',
        'Ask: if I doubt the conclusion, do the reasons still give me grounds to accept it?',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: '\'He\'s trustworthy because he always tells the truth.\' This is…',
          options: ['Valid proof', 'False dilemma', 'Hasty generalisation', 'Circular reasoning'],
          correctIndex: 3,
          explanation: '\'Trustworthy\' and \'always tells the truth\' are the same claim.',
        ),
        DailyLearningQuestion(
          prompt: 'What does a circular argument lack?',
          options: ['Long sentences', 'Independent evidence', 'Emotion', 'A conclusion'],
          correctIndex: 1,
          explanation: 'Its premises merely restate the conclusion.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_9',
      title: 'Day 9: Hasty generalisation',
      teachingPoints: [
        'A hasty generalisation draws a broad conclusion from too few or unrepresentative examples.',
        '\'Two students from that school were rude, so all its students are rude.\'',
        'Good conclusions need enough examples, chosen fairly.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: '\'I met one teacher from Bamenda who was strict; Bamenda teachers are strict.\' This is…',
          options: ['Red herring', 'Appeal to authority', 'Hasty generalisation', 'Circular reasoning'],
          correctIndex: 2,
          explanation: 'One example cannot represent a whole group.',
        ),
        DailyLearningQuestion(
          prompt: 'What would strengthen a generalisation?',
          options: ['A larger, representative sample', 'A louder voice', 'A single vivid story', 'Repeating it'],
          correctIndex: 0,
          explanation: 'More and fairer evidence.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_10',
      title: 'Day 10: Post hoc (false cause)',
      teachingPoints: [
        'Post hoc ergo propter hoc: \'after this, therefore because of this\'.',
        '\'I wore my lucky pen and passed — the pen made me pass.\'',
        'One event following another doesn\'t prove the first caused the second.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: '\'It rained after the football match, so the match caused the rain.\' This is…',
          options: ['Sound reasoning', 'Bandwagon', 'Straw man', 'Post hoc'],
          correctIndex: 3,
          explanation: 'Sequence is not causation.',
        ),
        DailyLearningQuestion(
          prompt: 'What would be needed to show cause?',
          options: ['Two events in a row', 'Evidence of a mechanism or a controlled comparison', 'A strong feeling', 'A famous opinion'],
          correctIndex: 1,
          explanation: 'Causation needs more than timing.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_11',
      title: 'Day 11: Red herring',
      teachingPoints: [
        'A red herring distracts from the real issue with an irrelevant topic.',
        'Asked about late homework: \'But have you seen how hard I worked on the football team?\'',
        'Notice when the subject changes, and return to the original question.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Asked why the generator wasn\'t fixed, the manager talks about last year\'s party. This is…',
          options: ['Circular reasoning', 'A false dilemma', 'A red herring', 'A fair answer'],
          correctIndex: 2,
          explanation: 'It changes the subject.',
        ),
        DailyLearningQuestion(
          prompt: 'A good response to a red herring is to…',
          options: ['Politely return to the original question', 'Follow the new topic', 'Leave', 'Agree'],
          correctIndex: 0,
          explanation: 'Bring the discussion back to the issue.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_12',
      title: 'Day 12: Tu quoque — \'you too\'',
      teachingPoints: [
        'Tu quoque dismisses criticism by pointing out the critic does the same thing.',
        'Parent: \'Smoking is bad for you.\' Child: \'But you smoke!\' — the health facts don\'t change.',
        'Hypocrisy may be real, but it doesn\'t make the argument false.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: '\'You say I should study more, but you didn\'t study at my age.\' This is…',
          options: ['Post hoc', 'Slippery slope', 'Appeal to nature', 'Tu quoque'],
          correctIndex: 3,
          explanation: 'Pointing to hypocrisy doesn\'t answer the advice.',
        ),
        DailyLearningQuestion(
          prompt: 'Does the critic\'s hypocrisy make the criticism false?',
          options: ['Yes, always', 'No, the argument must be judged on its own', 'Only for adults', 'Only in court'],
          correctIndex: 1,
          explanation: 'The claim stands or falls on its evidence.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_13',
      title: 'Day 13: Appeal to emotion',
      teachingPoints: [
        'An appeal to emotion uses feelings (fear, pity, pride) instead of evidence to win agreement.',
        'Emotion is not wrong in itself — the fallacy is when it replaces reasons.',
        'Ask: once I set the feeling aside, what evidence is left?',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'An advert shows crying children but gives no facts about the product. This relies on…',
          options: ['Appeal to authority', 'Circular reasoning', 'Appeal to emotion', 'Statistics'],
          correctIndex: 2,
          explanation: 'It moves feelings rather than giving reasons.',
        ),
        DailyLearningQuestion(
          prompt: 'When is emotion in an argument acceptable?',
          options: ['When it accompanies good evidence rather than replacing it', 'Never', 'Only in poems', 'Always'],
          correctIndex: 0,
          explanation: 'Feeling can motivate; evidence must persuade.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_14',
      title: 'Day 14: Correlation is not causation',
      teachingPoints: [
        'Two things that rise and fall together are correlated — that alone doesn\'t show one causes the other.',
        'Ice-cream sales and drownings both rise in hot weather; the heat drives both.',
        'Look for a third factor (a confounder) before claiming cause.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Students with more books at home score higher. What might ALSO explain it?',
          options: ['Nothing else', 'Luck only', 'The colour of the books', 'Family income or support (a third factor)'],
          correctIndex: 3,
          explanation: 'A confounding factor may cause both.',
        ),
        DailyLearningQuestion(
          prompt: 'Correlation means two things…',
          options: ['Always cause each other', 'Tend to vary together', 'Are identical', 'Never happen together'],
          correctIndex: 1,
          explanation: 'Correlation is association, not proof of cause.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_15',
      title: 'Day 15: Equivocation',
      teachingPoints: [
        'Equivocation switches between two meanings of the same word in one argument.',
        '\'A feather is light. What is light cannot be dark. So a feather cannot be dark.\'',
        'Check that key words keep the same meaning throughout.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'In the feather example, \'light\' first means…',
          options: ['Easy', 'Bright', 'Not heavy', 'Pale'],
          correctIndex: 2,
          explanation: 'Then it switches to \'not dark\'.',
        ),
        DailyLearningQuestion(
          prompt: 'Equivocation relies on…',
          options: ['A word with two meanings', 'Statistics', 'An expert', 'Fear'],
          correctIndex: 0,
          explanation: 'The argument trades on ambiguity.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_16',
      title: 'Day 16: Appeal to ignorance',
      teachingPoints: [
        'This fallacy claims something is true because it hasn\'t been proven false (or the reverse).',
        '\'Nobody has proved ghosts don\'t exist, so they do.\'',
        'Absence of evidence is a reason to stay unsure, not to conclude.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: '\'No one has shown the plan will fail, so it will succeed.\' This is…',
          options: ['Valid', 'Bandwagon', 'Tu quoque', 'Appeal to ignorance'],
          correctIndex: 3,
          explanation: 'Lack of disproof is not proof.',
        ),
        DailyLearningQuestion(
          prompt: 'If there is no evidence either way, the reasonable position is…',
          options: ['Believe it', 'Withhold judgment until there is evidence', 'Disbelieve it absolutely', 'Ask a celebrity'],
          correctIndex: 1,
          explanation: 'Stay open until evidence arrives.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_17',
      title: 'Day 17: Composition and division',
      teachingPoints: [
        'Composition: what is true of the parts must be true of the whole. Division: what is true of the whole must be true of each part.',
        '\'Each player is excellent, so the team will be excellent\' (composition) — teamwork matters too.',
        '\'The school is large, so every classroom is large\' (division).',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: '\'Every brick is light, so the wall is light.\' This is…',
          options: ['Post hoc', 'Division', 'Composition', 'Ad hominem'],
          correctIndex: 2,
          explanation: 'Properties of parts don\'t automatically transfer to the whole.',
        ),
        DailyLearningQuestion(
          prompt: '\'Cameroon is a big country, so every town in it is big.\' This is…',
          options: ['Division', 'Composition', 'Red herring', 'Straw man'],
          correctIndex: 0,
          explanation: 'A property of the whole isn\'t necessarily true of each part.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_18',
      title: 'Day 18: No true Scotsman',
      teachingPoints: [
        'This fallacy protects a claim by redefining the group to exclude counter-examples.',
        '\'No Ladybird student cheats.\' \'But Paul cheated.\' \'Then he\'s not a TRUE Ladybird student.\'',
        'Changing the definition after the fact avoids the evidence.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'What does the \'no true Scotsman\' move do?',
          options: ['Uses statistics', 'Asks for evidence', 'Agrees with the critic', 'Changes the definition to dismiss a counter-example'],
          correctIndex: 3,
          explanation: 'It shifts the goalposts.',
        ),
        DailyLearningQuestion(
          prompt: 'A fair response to a counter-example is to…',
          options: ['Redefine the group', 'Revise the original claim', 'Ignore it', 'Insult the person'],
          correctIndex: 1,
          explanation: 'Good reasoning updates the claim.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_19',
      title: 'Day 19: Loaded question',
      teachingPoints: [
        'A loaded question contains an assumption the person hasn\'t agreed to.',
        '\'Have you stopped copying homework?\' — either answer admits copying.',
        'Answer the hidden assumption, not just the question.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Which is a loaded question?',
          options: ['\'What time is it?\'', '\'Did you finish the essay?\'', '\'Why do you always lie?\'', '\'Where is the library?\''],
          correctIndex: 2,
          explanation: 'It assumes you always lie.',
        ),
        DailyLearningQuestion(
          prompt: 'The best response to a loaded question is to…',
          options: ['Point out the false assumption', 'Answer no', 'Answer yes', 'Stay silent forever'],
          correctIndex: 0,
          explanation: 'Challenge the assumption built into it.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_20',
      title: 'Day 20: Anecdotal evidence',
      teachingPoints: [
        'Anecdotal evidence uses a personal story in place of broader evidence.',
        '\'My uncle never wore a seatbelt and was fine, so seatbelts don\'t matter.\'',
        'Stories are memorable but can be exceptions; data shows the pattern.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Why is one survivor\'s story weak evidence about seatbelts?',
          options: ['It is too emotional', 'It is too recent', 'Uncles are unreliable', 'One case can be an exception to the overall pattern'],
          correctIndex: 3,
          explanation: 'Large studies show the real risk.',
        ),
        DailyLearningQuestion(
          prompt: 'Which is stronger evidence?',
          options: ['A friend\'s story', 'A study of thousands of accidents', 'A rumour', 'A single photo'],
          correctIndex: 1,
          explanation: 'Broad, systematic data.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_21',
      title: 'Day 21: Genetic fallacy',
      teachingPoints: [
        'The genetic fallacy judges a claim by where it came from rather than its merit.',
        '\'That idea came from a younger student, so it must be wrong.\'',
        'Good ideas can come from anywhere; test the idea itself.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: '\'That proposal is from the other school, so ignore it.\' This is…',
          options: ['False dilemma', 'Composition', 'Genetic fallacy', 'Equivocation'],
          correctIndex: 2,
          explanation: 'It rejects the idea because of its origin.',
        ),
        DailyLearningQuestion(
          prompt: 'To avoid the genetic fallacy, judge a claim by…',
          options: ['Its evidence and logic', 'Its source', 'Its age', 'Its length'],
          correctIndex: 0,
          explanation: 'Merit, not origin.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_22',
      title: 'Day 22: Appeal to nature',
      teachingPoints: [
        'This fallacy assumes \'natural\' means good or safe, and \'unnatural\' means bad.',
        '\'This remedy is natural, so it has no side effects.\' Many poisonous plants are natural.',
        'Ask for evidence of safety and effectiveness, natural or not.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Which is an appeal to nature?',
          options: ['\'Ask a pharmacist.\'', '\'Clinical trials found it safe.\'', '\'Read the dosage label.\'', '\'It\'s herbal, so it\'s safe.\''],
          correctIndex: 3,
          explanation: 'Natural does not guarantee safe.',
        ),
        DailyLearningQuestion(
          prompt: 'Is everything natural harmless?',
          options: ['Yes', 'No — many natural substances are toxic', 'Only plants', 'Only in Africa'],
          correctIndex: 1,
          explanation: 'Snake venom and some mushrooms are natural and dangerous.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_23',
      title: 'Day 23: Appeal to tradition',
      teachingPoints: [
        'This fallacy says something is right because it has always been done that way.',
        'Tradition can carry wisdom, but age alone doesn\'t prove a practice is best.',
        'Ask: what are the actual benefits and costs today?',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: '\'We\'ve always written reports by hand, so we shouldn\'t use computers.\' This is…',
          options: ['Post hoc', 'Straw man', 'Appeal to tradition', 'Bandwagon'],
          correctIndex: 2,
          explanation: 'Long practice isn\'t a reason by itself.',
        ),
        DailyLearningQuestion(
          prompt: 'A fair way to evaluate a tradition is to…',
          options: ['Weigh its present benefits and costs', 'Drop it automatically', 'Keep it automatically', 'Vote without discussion'],
          correctIndex: 0,
          explanation: 'Judge it on its merits.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_24',
      title: 'Day 24: Middle ground',
      teachingPoints: [
        'The middle-ground fallacy assumes the compromise between two positions must be correct.',
        'If one person says 2 + 2 = 4 and another says 6, the answer isn\'t 5.',
        'Compromise is useful in negotiation, not as a test of truth.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: '\'One expert says the bridge is safe, one says it isn\'t, so it\'s half-safe.\' This is…',
          options: ['Sound reasoning', 'Ad hominem', 'Hasty generalisation', 'Middle ground fallacy'],
          correctIndex: 3,
          explanation: 'The truth isn\'t automatically in the middle.',
        ),
        DailyLearningQuestion(
          prompt: 'When is the middle position right?',
          options: ['Always', 'Only when the evidence supports it', 'Never', 'When people are tired'],
          correctIndex: 1,
          explanation: 'Follow the evidence.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_25',
      title: 'Day 25: Special pleading',
      teachingPoints: [
        'Special pleading applies a rule to others but makes an exception for yourself without good reason.',
        '\'Late assignments lose marks — except mine, because I was busy.\'',
        'Ask: what makes this case genuinely different?',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: '\'Everyone must queue, but prefects can skip because they\'re prefects.\' This may be…',
          options: ['Post hoc', 'Equivocation', 'Special pleading', 'Circular reasoning'],
          correctIndex: 2,
          explanation: 'An exception is claimed without a relevant reason.',
        ),
        DailyLearningQuestion(
          prompt: 'An exception is justified when…',
          options: ['There is a relevant difference', 'It benefits you', 'You ask nicely', 'You are older'],
          correctIndex: 0,
          explanation: 'Relevant differences justify different treatment.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_26',
      title: 'Day 26: Burden of proof',
      teachingPoints: [
        'The person making a claim is responsible for supporting it.',
        '\'Prove my rumour is false!\' shifts the burden to the listener.',
        'Extraordinary claims need strong evidence from the person making them.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Who should provide evidence for a new claim?',
          options: ['The listener', 'A teacher', 'Nobody', 'The person making the claim'],
          correctIndex: 3,
          explanation: 'The claimant carries the burden of proof.',
        ),
        DailyLearningQuestion(
          prompt: '\'You can\'t prove I\'m wrong, so I\'m right\' shifts the…',
          options: ['Topic', 'Burden of proof', 'Definition', 'Timeline'],
          correctIndex: 1,
          explanation: 'It wrongly makes the critic responsible.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_27',
      title: 'Day 27: Texas sharpshooter',
      teachingPoints: [
        'The Texas sharpshooter picks out patterns in data after the fact and ignores the rest.',
        'Named after someone who shoots at a barn, then paints a target around the tightest cluster.',
        'Patterns should be predicted before looking, then tested on all the data.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Choosing only the three villages where a remedy \'worked\' and ignoring the twenty where it didn\'t is…',
          options: ['Tu quoque', 'Bandwagon', 'Texas sharpshooter', 'Equivocation'],
          correctIndex: 2,
          explanation: 'It cherry-picks clusters that fit.',
        ),
        DailyLearningQuestion(
          prompt: 'How do you avoid it?',
          options: ['State the pattern before checking and use all the data', 'Look for any pattern', 'Ignore outliers', 'Use fewer data'],
          correctIndex: 0,
          explanation: 'Pre-registered predictions and complete data.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_28',
      title: 'Day 28: Gambler\'s fallacy',
      teachingPoints: [
        'The gambler\'s fallacy believes past random results change future odds.',
        'A coin landed heads 5 times; tails is NOT \'due\' — each fair flip is still 50/50.',
        'Independent events have no memory.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'After 5 heads in a row with a fair coin, the chance of heads next is…',
          options: ['Less than 50%', '0%', 'More than 50%', '50%'],
          correctIndex: 3,
          explanation: 'Each flip is independent.',
        ),
        DailyLearningQuestion(
          prompt: '\'I\'ve lost many times, so I\'m due a win\' is…',
          options: ['Good probability', 'The gambler\'s fallacy', 'Composition', 'Anecdotal evidence'],
          correctIndex: 1,
          explanation: 'Past losses don\'t raise future chances.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_29',
      title: 'Day 29: Sunk cost',
      teachingPoints: [
        'The sunk-cost fallacy keeps investing because of what was already spent, not because of future value.',
        '\'I\'ve paid for the whole film, so I\'ll sit through it though I\'m bored.\'',
        'Decide based on future costs and benefits; past costs can\'t be recovered.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Which choice ignores sunk cost correctly?',
          options: ['Finishing a bad course because you paid', 'Spending more to \'save\' the first payment', 'Switching to a better option despite earlier spending', 'Never changing plans'],
          correctIndex: 2,
          explanation: 'Only future value should guide the decision.',
        ),
        DailyLearningQuestion(
          prompt: 'A sunk cost is a cost that…',
          options: ['Has already been paid and can\'t be recovered', 'Can be refunded', 'Will happen tomorrow', 'Is very small'],
          correctIndex: 0,
          explanation: 'It\'s gone either way.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'logical_fallacies_30',
      title: 'Day 30: Review: spotting fallacies in the wild',
      teachingPoints: [
        'Ask three questions: Is the evidence relevant? Is it enough? Are the options and definitions fair?',
        'Name the move, then answer the real issue — calling \'fallacy!\' isn\'t a rebuttal by itself.',
        'Apply the same standards to arguments you agree with.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: '\'Everyone knows our team is best, and anyone who disagrees is jealous.\' Which two fallacies?',
          options: ['No fallacy', 'Post hoc and composition', 'Equivocation and sunk cost', 'Bandwagon and ad hominem'],
          correctIndex: 3,
          explanation: 'Popularity as proof, then attacking disagreers.',
        ),
        DailyLearningQuestion(
          prompt: 'After naming a fallacy you should…',
          options: ['Stop talking', 'Explain why the reasoning fails and address the issue', 'Insult the speaker', 'Change the topic'],
          correctIndex: 1,
          explanation: 'Show the flaw, then engage with the substance.',
        ),
      ],
    ),
  ],
);

const DailyLearningCourse taxonomyCourse = DailyLearningCourse(
  id: 'taxonomy',
  title: 'Taxonomy',
  description: 'Understand how scientists name and classify every living thing.',
  lessons: [
    DailyLearningLesson(
      id: 'taxonomy_1',
      title: 'Day 1: Why classify living things?',
      teachingPoints: [
        'Taxonomy is the science of naming, describing and classifying organisms.',
        'Scientists have described about 2 million species; classification lets everyone refer to the same organism.',
        'Groups reflect shared features and, in modern taxonomy, shared ancestry.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Taxonomy is the science of…',
          options: ['Taxes', 'Weather', 'Naming and classifying organisms', 'Soil'],
          correctIndex: 2,
          explanation: 'From Greek taxis (arrangement) + nomos (law).',
        ),
        DailyLearningQuestion(
          prompt: 'Why do scientists need one system of names?',
          options: ['So everyone means the same organism', 'To make names longer', 'To sell books', 'It isn\'t needed'],
          correctIndex: 0,
          explanation: 'Common names vary between languages and regions.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_2',
      title: 'Day 2: Carl Linnaeus',
      teachingPoints: [
        'The Swedish botanist Carl Linnaeus (1707–1778) created the modern system of naming species.',
        'His books Species Plantarum (1753) and Systema Naturae (10th edition, 1758) are the starting points for scientific names.',
        'He grouped organisms in nested ranks, from broad to narrow.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Who is known as the father of modern taxonomy?',
          options: ['Charles Darwin', 'Louis Pasteur', 'Gregor Mendel', 'Carl Linnaeus'],
          correctIndex: 3,
          explanation: 'Linnaeus formalised binomial nomenclature.',
        ),
        DailyLearningQuestion(
          prompt: 'Linnaeus\'s system places organisms in…',
          options: ['Random lists', 'Nested ranks from broad to narrow', 'Alphabetical order', 'Order of size'],
          correctIndex: 1,
          explanation: 'Each rank sits inside the one above.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_3',
      title: 'Day 3: Binomial nomenclature',
      teachingPoints: [
        'Every species has a two-part scientific name: genus + species epithet.',
        'Humans are Homo sapiens; the lion is Panthera leo.',
        'Scientific names are usually Latin or Latinised, used worldwide.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'In \'Panthera leo\', \'Panthera\' is the…',
          options: ['Species epithet', 'Family', 'Genus', 'Kingdom'],
          correctIndex: 2,
          explanation: 'The first word is the genus.',
        ),
        DailyLearningQuestion(
          prompt: 'How many parts does a species name have?',
          options: ['Two', 'One', 'Three', 'Seven'],
          correctIndex: 0,
          explanation: 'Binomial means two names.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_4',
      title: 'Day 4: Writing scientific names',
      teachingPoints: [
        'The genus starts with a capital letter; the species epithet is all lower case.',
        'Both are written in italics (or underlined when handwritten): Homo sapiens.',
        'After the first mention, the genus can be shortened: H. sapiens.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Which is written correctly?',
          options: ['homo Sapiens', 'Homo Sapiens', 'HOMO SAPIENS', 'Homo sapiens (italic)'],
          correctIndex: 3,
          explanation: 'Capital genus, lower-case species, italicised.',
        ),
        DailyLearningQuestion(
          prompt: 'When handwriting a scientific name you should…',
          options: ['Put it in quotes', 'Underline it', 'Write it in capitals', 'Circle it'],
          correctIndex: 1,
          explanation: 'Underlining replaces italics in handwriting.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_5',
      title: 'Day 5: The ranks of classification',
      teachingPoints: [
        'Main ranks from broadest: Domain, Kingdom, Phylum, Class, Order, Family, Genus, Species.',
        'Memory aid: \'Dear King Philip Came Over For Good Soup\'.',
        'Organisms share more features the lower the rank they share.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Which rank is the most specific?',
          options: ['Kingdom', 'Family', 'Species', 'Phylum'],
          correctIndex: 2,
          explanation: 'Species is the narrowest main rank.',
        ),
        DailyLearningQuestion(
          prompt: 'Which comes directly after Class?',
          options: ['Order', 'Phylum', 'Genus', 'Family'],
          correctIndex: 0,
          explanation: '…Class, Order, Family…',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_6',
      title: 'Day 6: The three domains',
      teachingPoints: [
        'Life is grouped into three domains: Bacteria, Archaea and Eukarya.',
        'Bacteria and Archaea are prokaryotes — single cells with no nucleus.',
        'Eukarya contains all organisms whose cells have a nucleus: protists, fungi, plants and animals.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Which domain includes humans?',
          options: ['Bacteria', 'Archaea', 'Protista', 'Eukarya'],
          correctIndex: 3,
          explanation: 'Our cells have a nucleus.',
        ),
        DailyLearningQuestion(
          prompt: 'Prokaryotic cells lack…',
          options: ['DNA', 'A nucleus', 'A membrane', 'Ribosomes'],
          correctIndex: 1,
          explanation: 'Their DNA isn\'t enclosed in a nucleus.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_7',
      title: 'Day 7: Kingdoms of eukaryotes',
      teachingPoints: [
        'Traditional eukaryote kingdoms: Protista, Fungi, Plantae and Animalia.',
        'Plants make their own food by photosynthesis; animals and fungi take in food from other organisms.',
        '\'Protista\' is a mixed group of mostly single-celled eukaryotes that don\'t fit the others.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Which kingdom makes food by photosynthesis?',
          options: ['Animalia', 'Fungi', 'Plantae', 'None'],
          correctIndex: 2,
          explanation: 'Plants are autotrophs.',
        ),
        DailyLearningQuestion(
          prompt: 'A mushroom belongs to kingdom…',
          options: ['Fungi', 'Plantae', 'Animalia', 'Protista'],
          correctIndex: 0,
          explanation: 'Fungi absorb food; they don\'t photosynthesise.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_8',
      title: 'Day 8: What is a species?',
      teachingPoints: [
        'A common definition: a group of organisms that can interbreed and produce fertile offspring.',
        'A horse and donkey can produce a mule, but mules are usually sterile — so they are separate species.',
        'For organisms that don\'t reproduce sexually, scientists use shared features and DNA instead.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Why are horses and donkeys different species?',
          options: ['They look different', 'They eat different food', 'They live in different places', 'Their offspring (mules) are usually infertile'],
          correctIndex: 3,
          explanation: 'Fertile offspring is the test.',
        ),
        DailyLearningQuestion(
          prompt: 'For bacteria, species are mainly defined using…',
          options: ['Interbreeding', 'DNA and shared characteristics', 'Colour only', 'Size only'],
          correctIndex: 1,
          explanation: 'Bacteria reproduce asexually.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_9',
      title: 'Day 9: Bacteria',
      teachingPoints: [
        'Bacteria are single-celled prokaryotes found almost everywhere — soil, water, inside us.',
        'Most are harmless or helpful (digestion, making yoghurt, recycling nutrients); some cause diseases like cholera and typhoid.',
        'Antibiotics act against bacteria but not against viruses.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Which disease is caused by a bacterium?',
          options: ['Malaria', 'Influenza', 'Cholera', 'Ringworm'],
          correctIndex: 2,
          explanation: 'Cholera is caused by Vibrio cholerae; malaria by a protist; flu by a virus.',
        ),
        DailyLearningQuestion(
          prompt: 'Antibiotics work against…',
          options: ['Bacteria', 'Viruses', 'All germs', 'Fungi only'],
          correctIndex: 0,
          explanation: 'They don\'t treat viral infections.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_10',
      title: 'Day 10: Protists',
      teachingPoints: [
        'Protists are mostly single-celled eukaryotes: amoebae, algae, and parasites such as Plasmodium.',
        'Plasmodium, carried by Anopheles mosquitoes, causes malaria.',
        'Some protists photosynthesise like plants; others move and feed like animals.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Malaria is caused by…',
          options: ['A virus', 'A bacterium', 'A fungus', 'A protist (Plasmodium)'],
          correctIndex: 3,
          explanation: 'Plasmodium is a protist; the mosquito is only the carrier.',
        ),
        DailyLearningQuestion(
          prompt: 'Protists are…',
          options: ['Prokaryotes', 'Mostly single-celled eukaryotes', 'All plants', 'All animals'],
          correctIndex: 1,
          explanation: 'They have a nucleus.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_11',
      title: 'Day 11: Fungi',
      teachingPoints: [
        'Fungi include mushrooms, moulds and yeasts.',
        'They feed by absorbing nutrients, often from dead material — they are key decomposers.',
        'Their cell walls contain chitin, not cellulose like plants.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Yeast, used to make bread rise, is a…',
          options: ['Bacterium', 'Plant', 'Fungus', 'Protist'],
          correctIndex: 2,
          explanation: 'Yeasts are single-celled fungi.',
        ),
        DailyLearningQuestion(
          prompt: 'Fungi cell walls are made of…',
          options: ['Chitin', 'Cellulose', 'Bone', 'Wax'],
          correctIndex: 0,
          explanation: 'Chitin, also found in insect exoskeletons.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_12',
      title: 'Day 12: Plants',
      teachingPoints: [
        'Plants are multicellular eukaryotes that photosynthesise using chlorophyll.',
        'Their cell walls are made of cellulose.',
        'They range from mosses to giant trees like the African mahogany.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'The green pigment plants use to capture light is…',
          options: ['Haemoglobin', 'Keratin', 'Melanin', 'Chlorophyll'],
          correctIndex: 3,
          explanation: 'Chlorophyll absorbs light energy.',
        ),
        DailyLearningQuestion(
          prompt: 'Plant cell walls are made of…',
          options: ['Chitin', 'Cellulose', 'Protein', 'Calcium'],
          correctIndex: 1,
          explanation: 'Cellulose gives plants rigidity.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_13',
      title: 'Day 13: Plant groups',
      teachingPoints: [
        'Mosses: no true roots or vessels; reproduce with spores.',
        'Ferns: have vessels but still reproduce with spores.',
        'Gymnosperms (e.g. pines) have \'naked\' seeds in cones; angiosperms have flowers and seeds inside fruits.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Which plants produce flowers and fruits?',
          options: ['Mosses', 'Ferns', 'Angiosperms', 'Gymnosperms'],
          correctIndex: 2,
          explanation: 'Angiosperm = \'enclosed seed\'.',
        ),
        DailyLearningQuestion(
          prompt: 'Ferns reproduce using…',
          options: ['Spores', 'Seeds', 'Fruits', 'Cones'],
          correctIndex: 0,
          explanation: 'Ferns and mosses use spores.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_14',
      title: 'Day 14: Monocots and dicots',
      teachingPoints: [
        'Flowering plants are often split into monocots (one seed leaf) and dicots (two seed leaves).',
        'Monocots — maize, rice, plantain, grasses — have parallel leaf veins.',
        'Dicots — beans, cocoa, mango — have net-like leaf veins.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Maize is a…',
          options: ['Moss', 'Dicot', 'Fern', 'Monocot'],
          correctIndex: 3,
          explanation: 'One seed leaf, parallel veins.',
        ),
        DailyLearningQuestion(
          prompt: 'Net-like leaf veins suggest a…',
          options: ['Monocot', 'Dicot', 'Gymnosperm', 'Fungus'],
          correctIndex: 1,
          explanation: 'Dicots have branching veins.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_15',
      title: 'Day 15: Animals',
      teachingPoints: [
        'Animals are multicellular eukaryotes that eat other organisms and usually move at some stage.',
        'Their cells have no cell walls.',
        'They are split broadly into invertebrates (no backbone) and vertebrates (backbone).',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Animal cells, unlike plant cells, have no…',
          options: ['Nucleus', 'Membrane', 'Cell wall', 'DNA'],
          correctIndex: 2,
          explanation: 'That\'s why animals are flexible.',
        ),
        DailyLearningQuestion(
          prompt: 'Most animal species are…',
          options: ['Invertebrates', 'Vertebrates', 'Plants', 'Fungi'],
          correctIndex: 0,
          explanation: 'About 95% of animal species lack a backbone.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_16',
      title: 'Day 16: Chordates and vertebrates',
      teachingPoints: [
        'Phylum Chordata includes animals with a notochord at some stage of life.',
        'Vertebrates are chordates with a backbone: fish, amphibians, reptiles, birds and mammals.',
        'The backbone is made of vertebrae protecting the spinal cord.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Which group is NOT a vertebrate class?',
          options: ['Birds', 'Mammals', 'Fish', 'Insects'],
          correctIndex: 3,
          explanation: 'Insects are invertebrates (arthropods).',
        ),
        DailyLearningQuestion(
          prompt: 'The backbone protects the…',
          options: ['Heart', 'Spinal cord', 'Lungs', 'Stomach'],
          correctIndex: 1,
          explanation: 'Vertebrae surround the spinal cord.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_17',
      title: 'Day 17: Mammals',
      teachingPoints: [
        'Mammals feed their young on milk, have hair or fur, and are warm-blooded.',
        'Most give birth to live young; the platypus and echidnas lay eggs.',
        'Examples: humans, elephants, bats, whales, the gorillas of Cameroon\'s forests.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Which feature do ALL mammals share?',
          options: ['Laying eggs', 'Flying', 'Feeding young on milk', 'Living on land'],
          correctIndex: 2,
          explanation: 'Mammary glands give mammals their name.',
        ),
        DailyLearningQuestion(
          prompt: 'A whale is a mammal because it…',
          options: ['Breathes air and feeds its young milk', 'Swims', 'Is big', 'Eats fish'],
          correctIndex: 0,
          explanation: 'It\'s not a fish despite living in water.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_18',
      title: 'Day 18: Birds',
      teachingPoints: [
        'Birds have feathers, beaks, lay hard-shelled eggs and are warm-blooded.',
        'Most can fly, but ostriches and penguins cannot.',
        'Birds are descended from a group of dinosaurs.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Which feature is unique to birds today?',
          options: ['Wings', 'Warm blood', 'Eggs', 'Feathers'],
          correctIndex: 3,
          explanation: 'Bats and insects have wings; only birds have feathers.',
        ),
        DailyLearningQuestion(
          prompt: 'Can all birds fly?',
          options: ['Yes', 'No — e.g. ostriches cannot', 'Only at night', 'Only young birds'],
          correctIndex: 1,
          explanation: 'Flightless birds exist.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_19',
      title: 'Day 19: Reptiles',
      teachingPoints: [
        'Reptiles have dry, scaly skin and lay eggs with leathery shells on land.',
        'They are cold-blooded (ectothermic) — their body heat comes from the environment.',
        'Examples: snakes, lizards, crocodiles, tortoises.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Reptiles control body temperature mainly by…',
          options: ['Sweating', 'Shivering', 'Their environment, e.g. basking in sun', 'Fur'],
          correctIndex: 2,
          explanation: 'They are ectotherms.',
        ),
        DailyLearningQuestion(
          prompt: 'Which is a reptile?',
          options: ['Crocodile', 'Frog', 'Salamander', 'Toad'],
          correctIndex: 0,
          explanation: 'Frogs, toads and salamanders are amphibians.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_20',
      title: 'Day 20: Amphibians',
      teachingPoints: [
        'Amphibians usually start life in water (with gills) and live on land as adults (with lungs).',
        'Their moist skin can absorb oxygen and water.',
        'Examples: frogs, toads, salamanders — including the goliath frog of Cameroon, the world\'s largest frog.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'A tadpole becoming a frog is called…',
          options: ['Hibernation', 'Photosynthesis', 'Migration', 'Metamorphosis'],
          correctIndex: 3,
          explanation: 'A complete change in body form.',
        ),
        DailyLearningQuestion(
          prompt: 'The world\'s largest frog lives in…',
          options: ['Antarctica', 'Cameroon and Equatorial Guinea', 'Iceland', 'The Sahara'],
          correctIndex: 1,
          explanation: 'The goliath frog, Conraua goliath.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_21',
      title: 'Day 21: Fish',
      teachingPoints: [
        'Fish live in water, breathe with gills and usually have fins and scales.',
        'Bony fish (like tilapia) have skeletons of bone; cartilaginous fish (sharks, rays) of cartilage.',
        'Most are cold-blooded.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Fish breathe using…',
          options: ['Lungs', 'Skin only', 'Gills', 'Fins'],
          correctIndex: 2,
          explanation: 'Gills extract oxygen from water.',
        ),
        DailyLearningQuestion(
          prompt: 'A shark\'s skeleton is made of…',
          options: ['Cartilage', 'Bone', 'Chitin', 'Wood'],
          correctIndex: 0,
          explanation: 'Sharks are cartilaginous fish.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_22',
      title: 'Day 22: Arthropods',
      teachingPoints: [
        'Arthropods have jointed legs, segmented bodies and an exoskeleton made of chitin.',
        'They are the largest animal phylum: insects, spiders, crabs, millipedes.',
        'To grow, they must moult — shed their exoskeleton.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Which is NOT an arthropod?',
          options: ['Spider', 'Crab', 'Millipede', 'Earthworm'],
          correctIndex: 3,
          explanation: 'Earthworms are annelids with no jointed legs.',
        ),
        DailyLearningQuestion(
          prompt: 'Why must arthropods moult?',
          options: ['To change colour', 'Their rigid exoskeleton can\'t grow', 'To cool down', 'To lay eggs'],
          correctIndex: 1,
          explanation: 'They shed it and grow a larger one.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_23',
      title: 'Day 23: Insects',
      teachingPoints: [
        'Insects have three body parts (head, thorax, abdomen), six legs and usually two pairs of wings.',
        'Spiders have eight legs and two body parts — they are arachnids, not insects.',
        'Insects pollinate crops, but some (mosquitoes, tsetse flies) carry diseases.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'How many legs does an insect have?',
          options: ['Four', 'Eight', 'Six', 'Ten'],
          correctIndex: 2,
          explanation: 'Six legs on the thorax.',
        ),
        DailyLearningQuestion(
          prompt: 'A spider is an…',
          options: ['Arachnid', 'Insect', 'Amphibian', 'Crustacean'],
          correctIndex: 0,
          explanation: 'Eight legs, two body parts.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_24',
      title: 'Day 24: Molluscs and other invertebrates',
      teachingPoints: [
        'Molluscs have soft bodies, often protected by a shell: snails, clams, octopuses.',
        'Annelids are segmented worms like earthworms; cnidarians include jellyfish and corals.',
        'The giant African land snail is a large mollusc common in West and Central Africa.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'An octopus belongs to the…',
          options: ['Annelids', 'Arthropods', 'Fish', 'Molluscs'],
          correctIndex: 3,
          explanation: 'It is a mollusc without an external shell.',
        ),
        DailyLearningQuestion(
          prompt: 'An earthworm is a…',
          options: ['Mollusc', 'Segmented worm (annelid)', 'Insect', 'Reptile'],
          correctIndex: 1,
          explanation: 'Its body is made of repeated segments.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_25',
      title: 'Day 25: Dichotomous keys',
      teachingPoints: [
        'A dichotomous key identifies an organism through pairs of choices.',
        'Each step asks one yes/no-style question: \'Has six legs? → go to 4. Eight legs? → spider.\'',
        'Good keys use features you can observe, not behaviour or size alone.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: '\'Dichotomous\' means divided into…',
          options: ['Many', 'Three', 'Two', 'None'],
          correctIndex: 2,
          explanation: 'Each step splits into two options.',
        ),
        DailyLearningQuestion(
          prompt: 'Which makes a good key question?',
          options: ['\'Does it have six legs?\'', '\'Is it pretty?\'', '\'Is it my favourite?\'', '\'Is it rare?\''],
          correctIndex: 0,
          explanation: 'Clear, observable features.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_26',
      title: 'Day 26: Homologous and analogous structures',
      teachingPoints: [
        'Homologous structures share an origin but may have different jobs: a human arm, a bat wing, a whale flipper.',
        'Analogous structures do the same job but evolved separately: a bird wing and an insect wing.',
        'Homology is evidence of shared ancestry and guides classification.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'A bat\'s wing and a human arm are…',
          options: ['Analogous', 'Identical', 'Unrelated', 'Homologous'],
          correctIndex: 3,
          explanation: 'Same bone pattern, different use.',
        ),
        DailyLearningQuestion(
          prompt: 'A butterfly wing and a bird wing are…',
          options: ['Homologous', 'Analogous', 'The same organ', 'Both made of bone'],
          correctIndex: 1,
          explanation: 'Same function, different origins.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_27',
      title: 'Day 27: Classification by ancestry',
      teachingPoints: [
        'Modern taxonomy (cladistics) groups organisms by common ancestry.',
        'A phylogenetic tree shows how species branch from shared ancestors.',
        'DNA comparisons have moved some species — e.g. showing fungi are more closely related to animals than to plants.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'A phylogenetic tree shows…',
          options: ['Plant heights', 'Food chains', 'Evolutionary relationships', 'Climate'],
          correctIndex: 2,
          explanation: 'Branches represent descent from common ancestors.',
        ),
        DailyLearningQuestion(
          prompt: 'DNA evidence shows fungi are closest to…',
          options: ['Animals', 'Plants', 'Bacteria', 'Viruses'],
          correctIndex: 0,
          explanation: 'Surprising but well supported.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_28',
      title: 'Day 28: Classifying humans',
      teachingPoints: [
        'Domain Eukarya, Kingdom Animalia, Phylum Chordata, Class Mammalia.',
        'Order Primates, Family Hominidae, Genus Homo, Species Homo sapiens (\'wise human\').',
        'Our closest living relatives are chimpanzees and bonobos; gorillas are close too.',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Humans belong to order…',
          options: ['Carnivora', 'Hominidae', 'Rodentia', 'Primates'],
          correctIndex: 3,
          explanation: 'Hominidae is our family, Primates our order.',
        ),
        DailyLearningQuestion(
          prompt: '\'Homo sapiens\' roughly means…',
          options: ['Upright ape', 'Wise human', 'Tool maker', 'Strong man'],
          correctIndex: 1,
          explanation: 'Latin sapiens = wise.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_29',
      title: 'Day 29: Viruses: inside or outside?',
      teachingPoints: [
        'Viruses are not placed in any of the three domains.',
        'They have no cells and can only reproduce inside a host cell.',
        'They have their own classification system (families like Coronaviridae).',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'Why aren\'t viruses in the domains of life?',
          options: ['They are too big', 'They are plants', 'They have no cells and need a host to reproduce', 'They are all harmful'],
          correctIndex: 2,
          explanation: 'They lack cellular structure.',
        ),
        DailyLearningQuestion(
          prompt: 'Do antibiotics cure viral infections?',
          options: ['No', 'Yes', 'Only in children', 'Only flu'],
          correctIndex: 0,
          explanation: 'Antibiotics target bacteria.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'taxonomy_30',
      title: 'Day 30: Why taxonomy matters',
      teachingPoints: [
        'Classification helps protect biodiversity — you can\'t conserve what you can\'t name.',
        'Cameroon is one of Africa\'s most biodiverse countries, with many species found nowhere else (endemics).',
        'Correct identification matters in medicine, farming and food safety (e.g. telling edible from poisonous mushrooms).',
      ],
      questions: [
        DailyLearningQuestion(
          prompt: 'An endemic species is one that…',
          options: ['Is found everywhere', 'Is a pest', 'Is extinct', 'Is found naturally in only one region'],
          correctIndex: 3,
          explanation: 'Endemic = native to and restricted to one area.',
        ),
        DailyLearningQuestion(
          prompt: 'Why does accurate classification matter for medicine?',
          options: ['It doesn\'t', 'To identify disease organisms and medicinal plants correctly', 'To name hospitals', 'To count doctors'],
          correctIndex: 1,
          explanation: 'Treatment depends on knowing exactly what you\'re dealing with.',
        ),
      ],
    ),
  ],
);

const List<DailyLearningCourse> dailyLearningCourses = [
  etymologyCourse,
  fallaciesCourse,
  taxonomyCourse,
];
