import '../models/flashcard.dart';
import '../models/quiz_question.dart';
import '../models/study_deck.dart';

// ---------------------------------------------------------------------------
// بيانات تجريبية مؤقتة لاختبار الواجهة قبل ربط الذكاء الاصطناعي.
// احذف هذا الملف عندما تتوفر بيانات حقيقية.
// ---------------------------------------------------------------------------

const List<StudyDeck> sampleDecks = [
  StudyDeck(
    id: 'sample-bio',
    title: 'Cellular Respiration',
    subject: 'Biology',
    isSample: true,
    flashcards: [
      Flashcard(
        id: 'bio-c1',
        question: 'What is the main goal of cellular respiration?',
        answer:
            'To convert the chemical energy stored in glucose into ATP that the cell can use.',
      ),
      Flashcard(
        id: 'bio-c2',
        question: 'Where does glycolysis take place?',
        answer: 'In the cytoplasm.',
      ),
      Flashcard(
        id: 'bio-c3',
        question: 'What is the net ATP gain from glycolysis?',
        answer: '2 ATP per glucose molecule.',
      ),
      Flashcard(
        id: 'bio-c4',
        question: 'Where does the Krebs cycle occur?',
        answer: 'In the mitochondrial matrix.',
      ),
      Flashcard(
        id: 'bio-c5',
        question:
            'What is the final electron acceptor in the electron transport chain?',
        answer:
            'Oxygen. It combines with electrons and protons to form water.',
      ),
      Flashcard(
        id: 'bio-c6',
        question: 'What happens to pyruvate when oxygen is not available?',
        answer:
            'It goes through fermentation (for example, lactic acid in muscles) to regenerate NAD+.',
      ),
    ],
    quiz: [
      QuizQuestion(
        id: 'bio-q1',
        question: 'Which stage produces the most ATP?',
        options: [
          'Glycolysis',
          'Krebs cycle',
          'Electron transport chain',
          'Fermentation',
        ],
        correctIndex: 2,
        explanation:
            'Oxidative phosphorylation along the electron transport chain produces most of the ATP.',
      ),
      QuizQuestion(
        id: 'bio-q2',
        question: 'Glycolysis takes place in the:',
        options: ['Nucleus', 'Cytoplasm', 'Mitochondrial matrix', 'Ribosome'],
        correctIndex: 1,
      ),
      QuizQuestion(
        id: 'bio-q3',
        question: 'What is the end product of glycolysis?',
        options: ['Pyruvate', 'Acetyl-CoA', 'Lactic acid', 'Citrate'],
        correctIndex: 0,
      ),
      QuizQuestion(
        id: 'bio-q4',
        question: 'Which molecule is the final electron acceptor?',
        options: ['NAD+', 'FAD', 'Oxygen', 'Carbon dioxide'],
        correctIndex: 2,
      ),
      QuizQuestion(
        id: 'bio-q5',
        question: 'Which gas is released as waste during the Krebs cycle?',
        options: ['Oxygen', 'Nitrogen', 'Carbon dioxide', 'Hydrogen'],
        correctIndex: 2,
      ),
    ],
  ),
  StudyDeck(
    id: 'sample-econ',
    title: 'Supply & Demand',
    subject: 'Economics',
    isSample: true,
    flashcards: [
      Flashcard(
        id: 'econ-c1',
        question: 'What does the law of demand state?',
        answer:
            'As price rises, quantity demanded falls, assuming everything else stays the same.',
      ),
      Flashcard(
        id: 'econ-c2',
        question: 'What is market equilibrium?',
        answer:
            'The price at which quantity supplied equals quantity demanded.',
      ),
      Flashcard(
        id: 'econ-c3',
        question: 'What causes a shortage?',
        answer:
            'A price below equilibrium, so quantity demanded is greater than quantity supplied.',
      ),
      Flashcard(
        id: 'econ-c4',
        question: 'What is a substitute good?',
        answer: 'A good that can replace another, such as tea and coffee.',
      ),
      Flashcard(
        id: 'econ-c5',
        question: 'What does price elasticity of demand measure?',
        answer:
            'How strongly quantity demanded responds to a change in price.',
      ),
    ],
    quiz: [
      QuizQuestion(
        id: 'econ-q1',
        question: 'If the price is above equilibrium, the result is:',
        options: ['A shortage', 'A surplus', 'Equilibrium', 'Inflation'],
        correctIndex: 1,
        explanation:
            'Sellers offer more than buyers want at that price, so goods pile up.',
      ),
      QuizQuestion(
        id: 'econ-q2',
        question:
            'A rise in consumer income usually shifts demand for a normal good:',
        options: ['Left', 'Right', 'Not at all', 'Along the curve'],
        correctIndex: 1,
      ),
      QuizQuestion(
        id: 'econ-q3',
        question: 'Which of these shifts the supply curve?',
        options: [
          "A change in the good's own price",
          'A change in production costs',
          'A change in consumer tastes',
          "A change in buyers' income",
        ],
        correctIndex: 1,
        explanation:
            "The good's own price moves along the curve; tastes and income shift demand, not supply.",
      ),
      QuizQuestion(
        id: 'econ-q4',
        question: 'Demand is elastic when:',
        options: [
          'Quantity barely changes with price',
          'Quantity changes a lot with price',
          'Price never changes',
          'Supply is fixed',
        ],
        correctIndex: 1,
      ),
    ],
  ),
  StudyDeck(
    id: 'sample-cs-ar',
    title: 'أساسيات البرمجة',
    subject: 'علوم الحاسب',
    isSample: true,
    flashcards: [
      Flashcard(
        id: 'cs-c1',
        question: 'ما هو المتغير؟',
        answer: 'اسم تُخزَّن فيه قيمة يمكن تغييرها أثناء تشغيل البرنامج.',
      ),
      Flashcard(
        id: 'cs-c2',
        question: 'ما الفرق بين حلقة for وحلقة while؟',
        answer:
            'تُستخدم for غالبًا عندما يكون عدد التكرارات معروفًا، بينما تستمر while ما دام الشرط صحيحًا.',
      ),
      Flashcard(
        id: 'cs-c3',
        question: 'ما هي الدالة؟',
        answer:
            'مجموعة أوامر لها اسم، تُستدعى لتنفيذ مهمة محددة ويمكن أن تُرجع قيمة.',
      ),
      Flashcard(
        id: 'cs-c4',
        question: 'ماذا يعني أن القائمة تبدأ من الفهرس 0؟',
        answer: 'أن أول عنصر في القائمة رقمه 0 وليس 1.',
      ),
    ],
    quiz: [
      QuizQuestion(
        id: 'cs-q1',
        question: 'أي نوع بيانات يناسب تخزين الرقم 3.5؟',
        options: ['صحيح int', 'عشري double', 'نص String', 'منطقي bool'],
        correctIndex: 1,
      ),
      QuizQuestion(
        id: 'cs-q2',
        question: 'ما ناتج 7 % 3 ؟',
        options: ['1', '2', '3', '0'],
        correctIndex: 0,
        explanation: 'العامل % يعطي باقي القسمة، وباقي قسمة 7 على 3 هو 1.',
      ),
      QuizQuestion(
        id: 'cs-q3',
        question: 'ما القيم التي يأخذها النوع bool؟',
        options: ['أي رقم', 'نص فقط', 'true أو false', 'null فقط'],
        correctIndex: 2,
      ),
    ],
  ),
];
