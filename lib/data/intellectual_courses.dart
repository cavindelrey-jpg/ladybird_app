import '../models/daily_learning.dart';
final mathProofs = DailyLearningCourse(
  id: 'math_proofs',
  title: 'Mathematical Proofs',
  description: 'Explore the foundational proofs of mathematics.',
  lessons: [
    DailyLearningLesson(
      id: 'tri_180',
      title: 'Proving angles of triangle sum to 180',
      teachingPoints: const [
        'Draw a line parallel to one side of a triangle through the opposite vertex.',
        'Alternate interior angles are equal.',
        'The three angles form a straight line (180 degrees).',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is the key construction in this proof?',
          options: ['Draw a circle', 'Draw a parallel line', 'Measure the sides', 'Bisect an angle'],
          correctIndex: 1,
          explanation: 'Drawing a line parallel to one side allows using alternate interior angles.',
        ),
        DailyLearningQuestion(
          prompt: 'What property of parallel lines is used?',
          options: ['Corresponding angles', 'Alternate interior angles', 'Vertical angles', 'None'],
          correctIndex: 1,
          explanation: 'Alternate interior angles are equal when a transversal intersects parallel lines.',
        ),
        DailyLearningQuestion(
          prompt: 'What do the three angles form at the vertex?',
          options: ['A right angle', 'A straight line', 'A circle', 'A reflex angle'],
          correctIndex: 1,
          explanation: 'They form a straight line, which is 180 degrees.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'pythagorean',
      title: 'Pythagorean theorem',
      teachingPoints: const [
        'a^2 + b^2 = c^2 for a right triangle.',
        'Can be proved using four identical right triangles arranged in a square.',
        'The inner square has area c^2.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What type of triangle does the theorem apply to?',
          options: ['Equilateral', 'Isosceles', 'Right', 'Scalene'],
          correctIndex: 2,
          explanation: 'The Pythagorean theorem specifically applies to right-angled triangles.',
        ),
        DailyLearningQuestion(
          prompt: 'What is the formula?',
          options: ['a+b=c', 'a^2+b^2=c^2', 'a*b=c', 'a/b=c'],
          correctIndex: 1,
          explanation: 'The sum of the squares of the legs equals the square of the hypotenuse.',
        ),
        DailyLearningQuestion(
          prompt: 'In the geometric proof, what is the area of the inner square?',
          options: ['a^2', 'b^2', 'c^2', '(a+b)^2'],
          correctIndex: 2,
          explanation: 'The inner square is formed by the hypotenuses, so its area is c^2.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'infinite_primes',
      title: 'Infinite primes',
      teachingPoints: const [
        'Assume there are finitely many primes.',
        'Multiply them all and add 1.',
        'This new number is not divisible by any of the prime list, showing a contradiction.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'Who is credited with this proof?',
          options: ['Newton', 'Euclid', 'Euler', 'Gauss'],
          correctIndex: 1,
          explanation: "Euclid's Elements contains this classic proof by contradiction.",
        ),
        DailyLearningQuestion(
          prompt: 'What method of proof is used?',
          options: ['Direct', 'Contradiction', 'Induction', 'Construction'],
          correctIndex: 1,
          explanation: 'It assumes the opposite (finite primes) and finds a contradiction.',
        ),
        DailyLearningQuestion(
          prompt: 'What do we do to the list of all assumed primes?',
          options: ['Add them', 'Multiply them and add 1', 'Square them', 'Divide by 2'],
          correctIndex: 1,
          explanation: 'Multiplying them and adding 1 ensures it leaves a remainder of 1 when divided by any prime in the list.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'root_2',
      title: 'Root 2 is irrational',
      teachingPoints: const [
        'Assume sqrt(2) is rational (a/b in lowest terms).',
        'Then a^2 = 2b^2, meaning a^2 is even, so a is even.',
        'If a=2k, then 4k^2 = 2b^2, so b^2 = 2k^2, meaning b is also even, contradicting lowest terms.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What does it mean for a number to be rational?',
          options: ['It is an integer', 'It can be written as a fraction', 'It is positive', 'It is real'],
          correctIndex: 1,
          explanation: 'A rational number can be expressed as a ratio of integers a/b.',
        ),
        DailyLearningQuestion(
          prompt: "What does the proof deduce about 'a' and 'b' if a/b = sqrt(2)?",
          options: ['Both are odd', 'Both are even', 'One is zero', 'They are negative'],
          correctIndex: 1,
          explanation: 'It deduces both must be even, contradicting that they share no common factors.',
        ),
        DailyLearningQuestion(
          prompt: 'What type of proof is this?',
          options: ['Direct', 'Contradiction', 'Exhaustion', 'Induction'],
          correctIndex: 1,
          explanation: "It's a classic proof by contradiction.",
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'sum_odd',
      title: 'Sum of odd numbers',
      teachingPoints: const [
        'The sum of the first n odd numbers is n^2.',
        '1 = 1^2, 1+3=4=2^2, 1+3+5=9=3^2.',
        'Geometrically, adding the next odd number adds an L-shape to a square of dots to make the next square.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is the sum of the first 4 odd numbers?',
          options: ['16', '20', '12', '8'],
          correctIndex: 0,
          explanation: '1+3+5+7 = 16, which is 4^2.',
        ),
        DailyLearningQuestion(
          prompt: 'What is the general formula?',
          options: ['n', 'n^2', '2n', 'n(n+1)'],
          correctIndex: 1,
          explanation: 'The sum of the first n odd numbers is n^2.',
        ),
        DailyLearningQuestion(
          prompt: 'What visual shape does the next odd number form when added to a square?',
          options: ['Triangle', 'L-shape (gnomon)', 'Circle', 'Rectangle'],
          correctIndex: 1,
          explanation: 'It forms an L-shape that wraps around the existing square of dots.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'polygons',
      title: 'Polygons',
      teachingPoints: const [
        'The sum of interior angles of an n-sided polygon is (n-2)*180.',
        'Proved by dividing the polygon into triangles from one vertex.',
        'There are always n-2 triangles.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is the sum of angles in a quadrilateral?',
          options: ['180', '360', '540', '720'],
          correctIndex: 1,
          explanation: 'For a quadrilateral, n=4, so (4-2)*180 = 360.',
        ),
        DailyLearningQuestion(
          prompt: 'How many triangles can an octagon (n=8) be divided into from one vertex?',
          options: ['6', '7', '8', '4'],
          correctIndex: 0,
          explanation: 'n-2 = 8-2 = 6 triangles.',
        ),
        DailyLearningQuestion(
          prompt: 'What is each angle in a regular hexagon?',
          options: ['120', '90', '108', '135'],
          correctIndex: 0,
          explanation: 'Sum is (6-2)*180 = 720. 720/6 = 120.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'quad_formula',
      title: 'Quadratic formula',
      teachingPoints: const [
        "Derived by 'completing the square' on ax^2 + bx + c = 0.",
        'x = (-b +/- sqrt(b^2 - 4ac)) / 2a',
        'The discriminant (b^2 - 4ac) tells us how many real roots exist.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What method is used to derive the formula?',
          options: ['Factoring', 'Completing the square', 'Guess and check', 'Long division'],
          correctIndex: 1,
          explanation: 'Completing the square on the general form derives the formula.',
        ),
        DailyLearningQuestion(
          prompt: 'What part of the formula is the discriminant?',
          options: ['-b', '2a', 'b^2 - 4ac', 'sqrt(b)'],
          correctIndex: 2,
          explanation: 'The discriminant is the expression under the square root.',
        ),
        DailyLearningQuestion(
          prompt: 'If the discriminant is negative, how many real roots are there?',
          options: ['0', '1', '2', 'Infinite'],
          correctIndex: 0,
          explanation: 'A negative discriminant means no real roots (complex roots).',
        ),
      ],
    ),
  ],
);
final geometry = DailyLearningCourse(
  id: 'geometry',
  title: 'Geometry and Geometrical Proofs',
  description: 'Learn geometric concepts and classical constructions.',
  lessons: [
    DailyLearningLesson(
      id: 'constructions',
      title: 'Constructions',
      teachingPoints: const [
        'Using only a compass and straightedge.',
        'Can bisect angles and lines.',
        'Cannot trisect an arbitrary angle.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'Which tools are allowed in classical constructions?',
          options: ['Ruler and protractor', 'Compass and straightedge', 'Compass and protractor', 'Ruler and compass'],
          correctIndex: 1,
          explanation: 'Only a compass and an unmarked straightedge are used.',
        ),
        DailyLearningQuestion(
          prompt: 'Which of the following is impossible?',
          options: ['Bisecting a line', 'Bisecting an angle', 'Trisecting an angle', 'Drawing a perpendicular'],
          correctIndex: 2,
          explanation: 'Trisecting an arbitrary angle is impossible with classical tools.',
        ),
        DailyLearningQuestion(
          prompt: 'What does a compass draw?',
          options: ['Lines', 'Angles', 'Circles or arcs', 'Squares'],
          correctIndex: 2,
          explanation: 'A compass is used to draw circles or arcs.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'angle_rel',
      title: 'Angle relationships',
      teachingPoints: const [
        'Vertical angles are equal.',
        'Supplementary angles add to 180.',
        'Complementary angles add to 90.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What do supplementary angles add up to?',
          options: ['90', '180', '360', '45'],
          correctIndex: 1,
          explanation: 'Supplementary angles sum to 180 degrees.',
        ),
        DailyLearningQuestion(
          prompt: 'What are angles opposite each other at an intersection called?',
          options: ['Adjacent', 'Supplementary', 'Vertical', 'Complementary'],
          correctIndex: 2,
          explanation: 'Vertical angles are opposite and equal.',
        ),
        DailyLearningQuestion(
          prompt: 'If two complementary angles are equal, what is their measure?',
          options: ['45', '90', '180', '30'],
          correctIndex: 0,
          explanation: 'They add to 90, so 90/2 = 45.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'congruence',
      title: 'Congruence',
      teachingPoints: const [
        'Congruent figures have exactly the same shape and size.',
        'Triangles can be proved congruent by SSS, SAS, ASA, or AAS.',
        'AAA is not a congruence criterion.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'Which of these proves triangle congruence?',
          options: ['AAA', 'SSA', 'SAS', 'ASS'],
          correctIndex: 2,
          explanation: 'Side-Angle-Side (SAS) proves congruence.',
        ),
        DailyLearningQuestion(
          prompt: "What does 'congruent' mean?",
          options: ['Same shape, different size', 'Same shape, same size', 'Different shape, same size', 'Different everything'],
          correctIndex: 1,
          explanation: 'Congruent means identical in shape and size.',
        ),
        DailyLearningQuestion(
          prompt: 'Is AAA sufficient for congruence?',
          options: ['Yes', 'No', 'Only for right triangles', 'Only for equilateral triangles'],
          correctIndex: 1,
          explanation: 'AAA only proves similarity, not congruence.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'similarity',
      title: 'Similarity',
      teachingPoints: const [
        'Similar figures have the same shape but not necessarily the same size.',
        'Corresponding angles are equal.',
        'Corresponding sides are proportional.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is the ratio of corresponding sides called?',
          options: ['Scale factor', 'Congruence ratio', 'Slope', 'Area factor'],
          correctIndex: 0,
          explanation: 'The scale factor relates the lengths of corresponding sides.',
        ),
        DailyLearningQuestion(
          prompt: 'If a triangle is dilated by a factor of 2, what happens to its angles?',
          options: ['They double', 'They halve', 'They stay the same', 'They increase by 2'],
          correctIndex: 2,
          explanation: 'Similarity preserves angles; they stay the same.',
        ),
        DailyLearningQuestion(
          prompt: 'Which criterion works for similarity but not congruence?',
          options: ['SAS', 'SSS', 'AAA', 'ASA'],
          correctIndex: 2,
          explanation: 'Angle-Angle-Angle (AAA) proves similarity, but not congruence.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'circles',
      title: 'Circles',
      teachingPoints: const [
        'Area is pi * r^2.',
        'Circumference is 2 * pi * r.',
        'A tangent line is perpendicular to the radius at the point of tangency.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is the formula for circumference?',
          options: ['pi * r^2', '2 * pi * r', 'pi * d^2', '4 * pi * r'],
          correctIndex: 1,
          explanation: 'Circumference is 2*pi*r or pi*d.',
        ),
        DailyLearningQuestion(
          prompt: 'What angle does a tangent make with the radius?',
          options: ['45', '90', '180', '30'],
          correctIndex: 1,
          explanation: 'A tangent is always perpendicular (90 degrees) to the radius.',
        ),
        DailyLearningQuestion(
          prompt: 'If the radius doubles, what happens to the area?',
          options: ['Doubles', 'Triples', 'Quadruples', 'Halves'],
          correctIndex: 2,
          explanation: 'Area scales with the square of the radius, so 2^2 = 4 times.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'areas',
      title: 'Areas',
      teachingPoints: const [
        'Area of a triangle is 1/2 * base * height.',
        'Area of a parallelogram is base * height.',
        'Area is measured in square units.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is the area of a right triangle with legs 3 and 4?',
          options: ['6', '12', '7', '10'],
          correctIndex: 0,
          explanation: '1/2 * 3 * 4 = 6.',
        ),
        DailyLearningQuestion(
          prompt: "How does a parallelogram's area relate to a rectangle with the same base and height?",
          options: ['Half', 'Double', 'Same', 'Quarter'],
          correctIndex: 2,
          explanation: 'Both are base * height, so they are the same.',
        ),
        DailyLearningQuestion(
          prompt: 'What units are used for area?',
          options: ['Linear', 'Square', 'Cubic', 'None'],
          correctIndex: 1,
          explanation: 'Area is measured in square units.',
        ),
      ],
    ),
  ],
);
final mentalMath = DailyLearningCourse(
  id: 'mental_math',
  title: 'Mental Mathematics',
  description: 'Techniques for rapid mental calculation.',
  lessons: [
    DailyLearningLesson(
      id: 'mult_shortcuts',
      title: 'Multiplication shortcuts',
      teachingPoints: const [
        'To multiply by 10, add a 0.',
        'To multiply by 5, multiply by 10 and halve it.',
        'To multiply by 11, add the adjacent digits.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is 42 * 11?',
          options: ['462', '420', '442', '482'],
          correctIndex: 0,
          explanation: '4, 4+2=6, 2 -> 462.',
        ),
        DailyLearningQuestion(
          prompt: 'How can you easily multiply 64 by 5?',
          options: ['64*10 = 640, half is 320', '64*4+64', '60*5+20', 'Use a calculator'],
          correctIndex: 0,
          explanation: 'Multiply by 10 and divide by 2.',
        ),
        DailyLearningQuestion(
          prompt: 'What is 85 * 10?',
          options: ['805', '850', '855', '8500'],
          correctIndex: 1,
          explanation: 'Just add a zero.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'percentages',
      title: 'Percentage calculations',
      teachingPoints: const [
        '10% is just moving the decimal point one place left.',
        '5% is half of 10%.',
        '1% is moving the decimal two places left.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is 10% of 450?',
          options: ['45', '4.5', '4500', '90'],
          correctIndex: 0,
          explanation: 'Move decimal one place left: 45.',
        ),
        DailyLearningQuestion(
          prompt: 'What is 15% of 200?',
          options: ['20', '30', '15', '40'],
          correctIndex: 1,
          explanation: '10% is 20, 5% is 10, total is 30.',
        ),
        DailyLearningQuestion(
          prompt: 'What is 1% of 75?',
          options: ['7.5', '0.75', '750', '0.075'],
          correctIndex: 1,
          explanation: 'Move decimal two places left: 0.75.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'estimation',
      title: 'Estimation',
      teachingPoints: const [
        'Round numbers to 1 or 2 significant digits.',
        'Useful for checking if an exact answer is reasonable.',
        'Front-end estimation focuses on the largest place value.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'Estimate 412 + 589.',
          options: ['900', '1000', '1100', '1200'],
          correctIndex: 1,
          explanation: '400 + 600 = 1000.',
        ),
        DailyLearningQuestion(
          prompt: 'Estimate 19 * 31.',
          options: ['500', '600', '700', '800'],
          correctIndex: 1,
          explanation: '20 * 30 = 600.',
        ),
        DailyLearningQuestion(
          prompt: 'Why is estimation useful?',
          options: ['It is exact', 'It avoids math entirely', 'It checks for reasonableness', 'It is required for geometry'],
          correctIndex: 2,
          explanation: 'It helps quickly verify if a calculated answer makes sense.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'divisibility',
      title: 'Divisibility',
      teachingPoints: const [
        'A number is divisible by 3 if the sum of its digits is divisible by 3.',
        'Divisible by 4 if the last two digits are.',
        'Divisible by 9 if the sum of digits is divisible by 9.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'Is 123 divisible by 3?',
          options: ['Yes', 'No', 'Only on Tuesdays', "Can't be determined"],
          correctIndex: 0,
          explanation: '1+2+3=6, which is divisible by 3.',
        ),
        DailyLearningQuestion(
          prompt: 'Which is divisible by 4?',
          options: ['114', '116', '118', '122'],
          correctIndex: 1,
          explanation: "The last two digits '16' are divisible by 4.",
        ),
        DailyLearningQuestion(
          prompt: 'Is 459 divisible by 9?',
          options: ['Yes', 'No', 'Sometimes', 'Maybe'],
          correctIndex: 0,
          explanation: '4+5+9=18, which is divisible by 9.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'fractions',
      title: 'Fractions',
      teachingPoints: const [
        'To add fractions, you need a common denominator.',
        'To multiply, multiply straight across.',
        'To divide, multiply by the reciprocal.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is 1/2 + 1/4?',
          options: ['2/6', '3/4', '1/8', '2/4'],
          correctIndex: 1,
          explanation: '2/4 + 1/4 = 3/4.',
        ),
        DailyLearningQuestion(
          prompt: 'What is 1/2 * 1/3?',
          options: ['1/5', '1/6', '2/5', '3/2'],
          correctIndex: 1,
          explanation: '1*1 / 2*3 = 1/6.',
        ),
        DailyLearningQuestion(
          prompt: 'What is 1/2 divided by 1/2?',
          options: ['1/4', '1', '0', '2'],
          correctIndex: 1,
          explanation: 'Any non-zero number divided by itself is 1.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'squares',
      title: 'Squares',
      teachingPoints: const [
        'Squaring a number ending in 5: (10n+5)^2 = 100*n*(n+1) + 25.',
        'E.g., 25^2: 2*3=6, append 25 -> 625.',
        'Knowing squares up to 20 is very helpful.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is 35^2?',
          options: ['1225', '925', '1025', '1525'],
          correctIndex: 0,
          explanation: '3*4=12, append 25 -> 1225.',
        ),
        DailyLearningQuestion(
          prompt: 'What is 15^2?',
          options: ['125', '225', '325', '425'],
          correctIndex: 1,
          explanation: '1*2=2, append 25 -> 225.',
        ),
        DailyLearningQuestion(
          prompt: 'What is 12^2?',
          options: ['124', '144', '164', '184'],
          correctIndex: 1,
          explanation: '12*12 = 144.',
        ),
      ],
    ),
  ],
);
final logicCourse = DailyLearningCourse(
  id: 'logic',
  title: 'Logic and Deductive Reasoning',
  description: 'Learn about Logic and Deductive Reasoning',
  lessons: [
    DailyLearningLesson(
      id: 'deduction',
      title: 'Deduction',
      teachingPoints: const [
        'Deduction goes from general to specific.',
        'Syllogisms are a form of deduction.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is a syllogism?',
          options: ['A logical argument', 'A math formula', 'A type of bird', 'A fallacy'],
          correctIndex: 0,
          explanation: 'A syllogism is a logical argument form.',
        ),
        DailyLearningQuestion(
          prompt: 'Deduction moves from:',
          options: ['Specific to general', 'General to specific', 'Unknown to known', 'False to true'],
          correctIndex: 1,
          explanation: 'General premises lead to a specific conclusion.',
        ),
        DailyLearningQuestion(
          prompt: 'If all men are mortal and Socrates is a man...',
          options: ['He is a god', 'He is mortal', 'He is immortal', 'He is Greek'],
          correctIndex: 1,
          explanation: 'He must be mortal.',
        ),
      ],
    ),
  ],
);
final scientificCourse = DailyLearningCourse(
  id: 'scientific',
  title: 'Scientific Reasoning',
  description: 'Learn about Scientific Reasoning',
  lessons: [
    DailyLearningLesson(
      id: 'hypothesis',
      title: 'Hypothesis Testing',
      teachingPoints: const [
        'A hypothesis must be falsifiable.',
        'Experiments test hypotheses.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What makes a good hypothesis?',
          options: ['It is always true', 'It is falsifiable', 'It is complex', 'It is popular'],
          correctIndex: 1,
          explanation: 'It must be possible to prove it false.',
        ),
        DailyLearningQuestion(
          prompt: 'What tests a hypothesis?',
          options: ['Experiment', 'Opinion', 'Guessing', 'Debate'],
          correctIndex: 0,
          explanation: 'Experiments provide empirical data.',
        ),
        DailyLearningQuestion(
          prompt: 'Scientific reasoning relies on:',
          options: ['Dogma', 'Evidence', 'Authority', 'Intuition'],
          correctIndex: 1,
          explanation: 'It relies on empirical evidence.',
        ),
      ],
    ),
  ],
);
final estimationCourse = DailyLearningCourse(
  id: 'estimation',
  title: 'Estimation and Fermi Problems',
  description: 'Learn about Estimation and Fermi Problems',
  lessons: [
    DailyLearningLesson(
      id: 'fermi',
      title: 'Fermi Problems',
      teachingPoints: const [
        'Order of magnitude estimates.',
        'Named after Enrico Fermi.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is a Fermi problem?',
          options: ['An exact equation', 'An order of magnitude estimate', 'A paradox', 'A geometry proof'],
          correctIndex: 1,
          explanation: 'It involves making justified guesses.',
        ),
        DailyLearningQuestion(
          prompt: 'What is typically sought?',
          options: ['Exact precision', 'Order of magnitude', 'Zero error', 'Units only'],
          correctIndex: 1,
          explanation: 'Getting the power of 10 right.',
        ),
        DailyLearningQuestion(
          prompt: 'Who is it named after?',
          options: ['Newton', 'Einstein', 'Fermi', 'Bohr'],
          correctIndex: 2,
          explanation: 'Enrico Fermi.',
        ),
      ],
    ),
  ],
);
final memoryCourse = DailyLearningCourse(
  id: 'memory',
  title: 'Memory Techniques',
  description: 'Learn about Memory Techniques',
  lessons: [
    DailyLearningLesson(
      id: 'loci',
      title: 'Method of Loci',
      teachingPoints: const [
        'Also known as the memory palace.',
        'Associates items with physical locations.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is the memory palace technique?',
          options: ['Repeating words', 'Method of loci', 'Writing notes', 'Singing'],
          correctIndex: 1,
          explanation: 'Method of loci associates items with locations.',
        ),
        DailyLearningQuestion(
          prompt: "What does 'loci' mean?",
          options: ['Places', 'Times', 'Thoughts', 'Numbers'],
          correctIndex: 0,
          explanation: "It's Latin for places.",
        ),
        DailyLearningQuestion(
          prompt: 'Why does it work?',
          options: ['Magic', 'Spatial memory is strong', 'It uses repetition', 'It ignores visuals'],
          correctIndex: 1,
          explanation: 'Humans have excellent spatial memory.',
        ),
      ],
    ),
  ],
);
final argumentationCourse = DailyLearningCourse(
  id: 'argumentation',
  title: 'Argumentation and Clear Thinking',
  description: 'Learn about Argumentation and Clear Thinking',
  lessons: [
    DailyLearningLesson(
      id: 'premises',
      title: 'Premises and Conclusions',
      teachingPoints: const [
        'Arguments consist of premises supporting a conclusion.',
        'A sound argument is valid and has true premises.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What supports a conclusion?',
          options: ['Premises', 'Opinions', 'Fallacies', 'Questions'],
          correctIndex: 0,
          explanation: 'Premises provide the support.',
        ),
        DailyLearningQuestion(
          prompt: 'What is a valid argument?',
          options: ['It is always true', 'The conclusion follows logically from premises', 'It is persuasive', 'It is long'],
          correctIndex: 1,
          explanation: 'Validity is about the logical structure.',
        ),
        DailyLearningQuestion(
          prompt: 'What makes an argument sound?',
          options: ['Loudness', 'Validity plus true premises', 'Many premises', 'Good rhetoric'],
          correctIndex: 1,
          explanation: 'Soundness requires truth and validity.',
        ),
      ],
    ),
  ],
);
final fallaciesCourse = DailyLearningCourse(
  id: 'fallacies',
  title: 'Logical Fallacies',
  description: 'Learn about Logical Fallacies',
  lessons: [
    DailyLearningLesson(
      id: 'ad_hominem',
      title: 'Ad Hominem',
      teachingPoints: const [
        'Attacking the person instead of the argument.',
        'A fallacy of relevance.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is Ad Hominem?',
          options: ['Attacking the argument', 'Attacking the person', 'Using false data', 'Appealing to emotion'],
          correctIndex: 1,
          explanation: 'It targets the speaker, not their point.',
        ),
        DailyLearningQuestion(
          prompt: 'Why is it a fallacy?',
          options: ["It's rude", "The person's character is irrelevant to the logic", "It's too long", "It's not a fallacy"],
          correctIndex: 1,
          explanation: "Personal traits don't change logical validity.",
        ),
        DailyLearningQuestion(
          prompt: 'Is name-calling always an ad hominem fallacy?',
          options: ['Yes', 'No, only if used to dismiss an argument', 'Always in politics', 'Never'],
          correctIndex: 1,
          explanation: "It's a fallacy when used as an argument substitute.",
        ),
      ],
    ),
  ],
);
final vocabCourse = DailyLearningCourse(
  id: 'vocab',
  title: 'Vocabulary and Greek and Latin Roots',
  description: 'Learn about Vocabulary and Greek and Latin Roots',
  lessons: [
    DailyLearningLesson(
      id: 'intro',
      title: 'Roots',
      teachingPoints: const [
        'Many English words come from Greek and Latin.',
        'Knowing roots helps decode new words.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What language provides many science roots?',
          options: ['Greek', 'French', 'German', 'Spanish'],
          correctIndex: 0,
          explanation: 'Greek provides many scientific terms.',
        ),
        DailyLearningQuestion(
          prompt: "What does 'dict' mean?",
          options: ['Write', 'Speak', 'See', 'Hear'],
          correctIndex: 1,
          explanation: 'Dict means to speak or say.',
        ),
        DailyLearningQuestion(
          prompt: 'Why learn roots?',
          options: ['To speak Greek', 'To decode new English words', 'To write poems', 'To spell better'],
          correctIndex: 1,
          explanation: 'They act as building blocks for meaning.',
        ),
      ],
    ),
  ],
);
final patternCourse = DailyLearningCourse(
  id: 'pattern',
  title: 'Pattern Recognition',
  description: 'Learn about Pattern Recognition',
  lessons: [
    DailyLearningLesson(
      id: 'sequences',
      title: 'Sequences',
      teachingPoints: const [
        'Look for differences or ratios.',
        'Fibonacci sequence adds previous two terms.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is the next number: 2, 4, 6, 8...',
          options: ['9', '10', '12', '14'],
          correctIndex: 1,
          explanation: 'Adds 2 each time.',
        ),
        DailyLearningQuestion(
          prompt: 'What is the Fibonacci sequence?',
          options: ['Multiply by 2', 'Add the previous two terms', 'Square the number', 'Subtract 1'],
          correctIndex: 1,
          explanation: 'Each term is the sum of the two preceding ones.',
        ),
        DailyLearningQuestion(
          prompt: 'What is 1, 4, 9, 16...?',
          options: ['Primes', 'Squares', 'Evens', 'Odds'],
          correctIndex: 1,
          explanation: 'They are perfect squares.',
        ),
      ],
    ),
  ],
);
final observationCourse = DailyLearningCourse(
  id: 'observation',
  title: 'Observation Skills',
  description: 'Learn about Observation Skills',
  lessons: [
    DailyLearningLesson(
      id: 'details',
      title: 'Noticing Details',
      teachingPoints: const [
        'Sherlock Holmes relied on observation.',
        'Distinguish between seeing and observing.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is the difference between seeing and observing?',
          options: ['None', 'Observing requires active attention', 'Seeing is harder', 'Observing is only with tools'],
          correctIndex: 1,
          explanation: 'Observation is active and analytical.',
        ),
        DailyLearningQuestion(
          prompt: 'Who is a famous fictional observer?',
          options: ['Batman', 'Sherlock Holmes', 'Iron Man', 'Superman'],
          correctIndex: 1,
          explanation: 'Holmes is famous for his deductive observation.',
        ),
        DailyLearningQuestion(
          prompt: 'Why is it useful?',
          options: ['To memorize', 'To gather data others miss', 'To read fast', 'To sleep better'],
          correctIndex: 1,
          explanation: 'It provides crucial missing information.',
        ),
      ],
    ),
  ],
);
final explanationCourse = DailyLearningCourse(
  id: 'explanation',
  title: 'Explanation and Communication',
  description: 'Learn about Explanation and Communication',
  lessons: [
    DailyLearningLesson(
      id: 'feynman',
      title: 'Feynman Technique',
      teachingPoints: const [
        'Explain it simply.',
        "If you can't, you don't understand it well enough.",
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is the Feynman Technique?',
          options: ['Reading a lot', 'Explaining a concept simply', 'Taking tests', 'Memorizing facts'],
          correctIndex: 1,
          explanation: 'It tests understanding through simple explanation.',
        ),
        DailyLearningQuestion(
          prompt: 'What if you use jargon?',
          options: ['You sound smart', 'You might be hiding a lack of understanding', 'It is better', 'Feynman would approve'],
          correctIndex: 1,
          explanation: 'Jargon can mask a lack of true comprehension.',
        ),
        DailyLearningQuestion(
          prompt: 'Who was Richard Feynman?',
          options: ['A biologist', 'A physicist', 'A chemist', 'A writer'],
          correctIndex: 1,
          explanation: 'He was a Nobel-winning physicist known for clear explanations.',
        ),
      ],
    ),
  ],
);
final historicalCourse = DailyLearningCourse(
  id: 'historical',
  title: 'Historical Reasoning',
  description: 'Learn about Historical Reasoning',
  lessons: [
    DailyLearningLesson(
      id: 'sources',
      title: 'Primary Sources',
      teachingPoints: const [
        'Primary sources are from the time period.',
        'Secondary sources analyze them.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is a primary source?',
          options: ['A textbook', 'A diary from the era', 'A modern documentary', 'A Wikipedia article'],
          correctIndex: 1,
          explanation: 'It is a first-hand account.',
        ),
        DailyLearningQuestion(
          prompt: 'What is a secondary source?',
          options: ['A letter', 'A photograph', 'An analysis of primary sources', 'An artifact'],
          correctIndex: 2,
          explanation: 'It analyzes and interprets primary sources.',
        ),
        DailyLearningQuestion(
          prompt: 'Why evaluate sources?',
          options: ['For bias and reliability', 'To memorize dates', 'To copy them', 'To sell them'],
          correctIndex: 1,
          explanation: 'All sources have context and potential bias.',
        ),
      ],
    ),
  ],
);
final reverseengCourse = DailyLearningCourse(
  id: 'reverse_eng',
  title: 'Reverse Engineering',
  description: 'Learn about Reverse Engineering',
  lessons: [
    DailyLearningLesson(
      id: 'deconstruct',
      title: 'Deconstruction',
      teachingPoints: const [
        'Taking things apart to see how they work.',
        'Applies to hardware, software, and ideas.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What is reverse engineering?',
          options: ['Building something new', 'Deconstructing to understand', 'Selling products', 'Writing code'],
          correctIndex: 1,
          explanation: 'It involves working backward from the finished product.',
        ),
        DailyLearningQuestion(
          prompt: 'Can it apply to software?',
          options: ['Yes', 'No', 'Only in the 90s', 'Only for games'],
          correctIndex: 0,
          explanation: 'Software is frequently reverse-engineered.',
        ),
        DailyLearningQuestion(
          prompt: 'What is a common reason to do it?',
          options: ['To understand or interoperate', 'To waste time', 'To break things permanently', 'To hide secrets'],
          correctIndex: 0,
          explanation: 'It helps in learning, fixing, and ensuring compatibility.',
        ),
      ],
    ),
  ],
);

final List<DailyLearningCourse> intellectualCourses = [mathProofs, geometry, mentalMath, logicCourse, scientificCourse, estimationCourse, memoryCourse, argumentationCourse, fallaciesCourse, vocabCourse, patternCourse, observationCourse, explanationCourse, historicalCourse, reverseengCourse];
