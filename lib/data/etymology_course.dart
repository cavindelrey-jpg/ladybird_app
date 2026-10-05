// lib/data/etymology_course.dart
// The first Daily Learning course (see models/daily_learning.dart for
// why content lives here in code rather than Firestore). Five short
// Greek/Latin root-word lessons, each teachable in under a minute and
// followed by a 3-question quiz -- sized for a genuine "one short daily
// session," not a full etymology syllabus.

import '../models/daily_learning.dart';
import 'intellectual_courses.dart';

final DailyLearningCourse etymologyCourse = DailyLearningCourse(
  id: 'etymology',
  title: 'Etymology',
  description: 'Learn the Greek and Latin roots behind everyday English words.',
  lessons: [
    DailyLearningLesson(
      id: 'bio_logy',
      title: 'Greek Roots: bio- and -logy',
      teachingPoints: const [
        '"bio-" comes from the Greek "bios," meaning life.',
        '"-logy" comes from the Greek "logos," meaning study of / word.',
        'Put together, "biology" literally means "the study of life."',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'What does the root "bio-" mean?',
          options: ['Light', 'Life', 'Sound', 'Distance'],
          correctIndex: 1,
          explanation: '"bio-" comes from the Greek "bios," meaning life.',
        ),
        DailyLearningQuestion(
          prompt: 'A "biography" is best described as:',
          options: [
            'A study of light',
            'A written account of someone\'s life',
            'A map of a country',
            'A type of rock',
          ],
          correctIndex: 1,
          explanation: '"bio-" (life) + "-graphy" (writing) = a written account of a life.',
        ),
        DailyLearningQuestion(
          prompt: 'Which word means "the study of the mind"?',
          options: ['Psychology', 'Geology', 'Biodegradable', 'Telegraph'],
          correctIndex: 0,
          explanation: '"psycho-" (mind) + "-logy" (study of) = psychology.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'port_dict',
      title: 'Latin Roots: port- and dict-',
      teachingPoints: const [
        '"port" comes from Latin "portare," meaning to carry.',
        '"dict" comes from Latin "dicere," meaning to speak or say.',
        'So "transport" means "to carry across," and "predict" means "to say beforehand."',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'The root "port" means:',
          options: ['To carry', 'To speak', 'To see', 'To write'],
          correctIndex: 0,
          explanation: '"port" comes from Latin "portare," to carry.',
        ),
        DailyLearningQuestion(
          prompt: 'Which word contains a root meaning "to speak"?',
          options: ['Import', 'Portable', 'Verdict', 'Airport'],
          correctIndex: 2,
          explanation: '"verdict" comes from "ver-" (true) + "dict" (to speak) -- "to speak the truth."',
        ),
        DailyLearningQuestion(
          prompt: 'To "contradict" someone means to:',
          options: [
            'Carry something for them',
            'Speak against what they said',
            'Photograph them',
            'Study them',
          ],
          correctIndex: 1,
          explanation: '"contra-" (against) + "dict" (to speak) = to speak against.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'photo_graph',
      title: 'Greek Roots: photo- and -graph',
      teachingPoints: const [
        '"photo-" comes from the Greek "phos," meaning light.',
        '"-graph" comes from the Greek "graphein," meaning to write or draw.',
        'A "photograph" is literally "light-writing" -- an image drawn by light.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'The root "photo-" relates to:',
          options: ['Sound', 'Light', 'Distance', 'Time'],
          correctIndex: 1,
          explanation: '"photo-" comes from the Greek "phos," meaning light.',
        ),
        DailyLearningQuestion(
          prompt: 'Which word uses "-graph" to mean "write/draw"?',
          options: ['Photosynthesis', 'Autograph', 'Biology', 'Portable'],
          correctIndex: 1,
          explanation: '"auto-" (self) + "-graph" (write) = a self-written signature.',
        ),
        DailyLearningQuestion(
          prompt: 'A "telegraph" sends messages using a root that means:',
          options: ['Far/distant', 'Life', 'Carry', 'Study'],
          correctIndex: 0,
          explanation: '"tele-" means far or distant, so "telegraph" is "distant writing."',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'spect_scrib',
      title: 'Latin Roots: spect- and scrib-',
      teachingPoints: const [
        '"spect" comes from Latin "spectare," meaning to look or watch.',
        '"scrib"/"script" comes from Latin "scribere," meaning to write.',
        'So "inspect" means "to look into," and "describe" means "to write down."',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'The root "spect" means:',
          options: ['To carry', 'To look', 'To speak', 'To grow'],
          correctIndex: 1,
          explanation: '"spect" comes from Latin "spectare," to look or watch.',
        ),
        DailyLearningQuestion(
          prompt: 'A "manuscript" is:',
          options: [
            'Something looked at closely',
            'Something written by hand',
            'A distant sound',
            'A study of life',
          ],
          correctIndex: 1,
          explanation: '"manu-" (hand) + "script" (written) = written by hand.',
        ),
        DailyLearningQuestion(
          prompt: 'To "respect" someone literally means to:',
          options: ['Write about them', 'Look back/again at them', 'Carry them', 'Speak for them'],
          correctIndex: 1,
          explanation: '"re-" (again) + "spect" (look) = to look at again, i.e. hold in regard.',
        ),
      ],
    ),
    DailyLearningLesson(
      id: 'tele_phon',
      title: 'Greek Roots: tele- and phon-',
      teachingPoints: const [
        '"tele-" comes from the Greek "tele," meaning far or distant.',
        '"phon" comes from the Greek "phone," meaning sound or voice.',
        'A "telephone" is literally a "distant voice" -- a device for hearing someone far away.',
      ],
      questions: const [
        DailyLearningQuestion(
          prompt: 'The root "phon" relates to:',
          options: ['Light', 'Sound/voice', 'Writing', 'Life'],
          correctIndex: 1,
          explanation: '"phon" comes from the Greek "phone," meaning sound or voice.',
        ),
        DailyLearningQuestion(
          prompt: 'A "symphony" combines "sym-" (together) with "phon" to mean:',
          options: [
            'Sounds together, i.e. music played in harmony',
            'A distant photograph',
            'A written life story',
            'A study of light',
          ],
          correctIndex: 0,
          explanation: '"sym-" (together) + "phon" (sound) = sounds combined in harmony.',
        ),
        DailyLearningQuestion(
          prompt: 'Which word uses "tele-" to mean "far/distant"?',
          options: ['Microphone', 'Television', 'Manuscript', 'Biodegradable'],
          correctIndex: 1,
          explanation: '"tele-" (far) + "vision" (sight) = seeing something from far away.',
        ),
      ],
    ),
  ],
);

/// Registry of every Daily Learning course -- currently just Etymology.
/// Adding a second subject later means adding one more entry here, not
/// restructuring anything in the repository or UI layer.
final List<DailyLearningCourse> dailyLearningCourses = [etymologyCourse, ...intellectualCourses];
