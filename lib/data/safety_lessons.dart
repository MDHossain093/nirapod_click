import '../models/safety_lesson.dart';

/// Static safety lessons for the Learn Center.
///
/// Everything is compiled into the app — no API calls, no Firebase, no Gemini.
/// Add or edit lessons here to ship new content in the next release.
const List<SafetyLesson> safetyLessons = [
  SafetyLesson(
    id: 'otp',
    titleEn: 'OTP Scams',
    titleBn: 'ওটিপি প্রতারণা',
    subtitleEn: 'Protect your verification codes',
    subtitleBn: 'আপনার যাচাইকরণ কোড সুরক্ষিত রাখুন',
    categoryEn: 'Payments',
    categoryBn: 'পেমেন্ট',
    icon: '🔐',
    minutes: 5,
    sections: [
      LessonSection(
        titleEn: 'What is an OTP?',
        titleBn: 'ওটিপি কী?',
        contentEn:
            'An OTP is a one-time verification code used '
            'to confirm an action or login.',
        contentBn:
            'ওটিপি হলো একটি একবার-ব্যবহারযোগ্য যাচাইকরণ কোড '
            'যা কোনো কাজ বা লগইন নিশ্চিত করতে ব্যবহৃত হয়।',
        tipsEn: [
          'Never share your OTP with another person.',
          'A legitimate support agent should not ask for your OTP.',
          'Never enter an OTP on an unfamiliar website.',
        ],
        tipsBn: [
          'আপনার ওটিপি অন্য কারো সাথে শেয়ার করবেন না।',
          'বৈধ সহায়তা এজেন্ট কখনো আপনার ওটিপি চাইবে না।',
          'অপরিচিত ওয়েবসাইটে ওটিপি লিখবেন না।',
        ],
      ),
      LessonSection(
        titleEn: 'Common scam pattern',
        titleBn: 'সাধারণ প্রতারণার ধরন',
        contentEn:
            'Scammers may pretend to be from a bank, '
            'mobile financial service, delivery company, '
            'or another trusted organization.',
        contentBn:
            'প্রতারকরা ব্যাংক, মোবাইল ফিন্যান্সিয়াল সার্ভিস, '
            'ডেলিভারি কোম্পানি বা অন্য কোনো বিশ্বস্ত সংস্থার '
            'প্রতিনিধি সেজে কথা বলতে পারে।',
        tipsEn: [
          'Do not trust urgent requests automatically.',
          'Verify through the organization\'s official channel.',
          'Never transfer money just because someone asks you to.',
        ],
        tipsBn: [
          'জরুরি অনুরোধ স্বয়ংক্রিয়ভাবে বিশ্বাস করবেন না।',
          'সংস্থার অফিসিয়াল মাধ্যমে যাচাই করুন।',
          'কেউ অনুরোধ করলেই টাকা পাঠাবেন না।',
        ],
      ),
    ],
  ),

  SafetyLesson(
    id: 'phishing',
    titleEn: 'Phishing Links',
    titleBn: 'ফিশিং লিংক',
    subtitleEn: 'Learn to recognize suspicious URLs',
    subtitleBn: 'সন্দেহজনক URL চিনতে শিখুন',
    categoryEn: 'Links',
    categoryBn: 'লিংক',
    icon: '🔗',
    minutes: 4,
    sections: [
      LessonSection(
        titleEn: 'What is phishing?',
        titleBn: 'ফিশিং কী?',
        contentEn:
            'Phishing is an attempt to trick you into '
            'visiting a fake website or giving away '
            'sensitive information.',
        contentBn:
            'ফিশিং হলো আপনাকে ভুয়া ওয়েবসাইটে ভিজিট করতে '
            'বা সংবেদনশীল তথ্য দিতে প্রতারণা করার চেষ্টা।',
        tipsEn: [
          'Check the domain carefully.',
          'Be cautious with shortened links.',
          'Do not enter passwords on unfamiliar websites.',
        ],
        tipsBn: [
          'ডোমেইন সাবধানে দেখুন।',
          'শর্টেন করা লিংক সম্পর্কে সতর্ক থাকুন।',
          'অপরিচিত ওয়েবসাইটে পাসওয়ার্ড দেবেন না।',
        ],
      ),
      LessonSection(
        titleEn: 'Before opening a link',
        titleBn: 'লিংক খোলার আগে',
        contentEn:
            'Look carefully at the address before '
            'opening or entering information.',
        contentBn:
            'লিংক খোলার বা তথ্য দেওয়ার আগে ঠিকানা '
            'সাবধানে দেখুন।',
        tipsEn: [
          'Check spelling of the domain.',
          'Be suspicious of unusual subdomains.',
          'Do not trust a link just because a brand name appears in it.',
        ],
        tipsBn: [
          'ডোমেইনের বানান পরীক্ষা করুন।',
          'অস্বাভাবিক সাবডোমেইন সম্পর্কে সন্দিগ্ধ থাকুন।',
          'ব্র্যান্ড নাম থাকলেই লিংক বিশ্বাস করবেন না।',
        ],
      ),
    ],
  ),

  SafetyLesson(
    id: 'fake-job',
    titleEn: 'Fake Job Offers',
    titleBn: 'ভুয়া চাকরির অফার',
    subtitleEn: 'Identify recruitment scams',
    subtitleBn: 'নিয়োগ সংক্রান্ত প্রতারণা চিনুন',
    categoryEn: 'Jobs',
    categoryBn: 'চাকরি',
    icon: '💼',
    minutes: 5,
    sections: [
      LessonSection(
        titleEn: 'Warning signs',
        titleBn: 'সতর্কতার চিহ্ন',
        contentEn:
            'Fake job offers often promise unusually high '
            'income and ask candidates for money or sensitive information.',
        contentBn:
            'ভুয়া চাকরির অফারে সাধারণত অস্বাভাবিক উচ্চ আয়ের '
            'প্রতিশ্রুতি দেওয়া হয় এবং প্রার্থীদের কাছ থেকে টাকা '
            'বা সংবেদনশীল তথ্য চাওয়া হয়।',
        tipsEn: [
          'Do not pay a recruitment fee without verification.',
          'Verify the company independently.',
          'Be careful with requests for OTP or banking information.',
        ],
        tipsBn: [
          'যাচাই ছাড়া নিয়োগ ফি দেবেন না।',
          'কোম্পানি স্বতন্ত্রভাবে যাচাই করুন।',
          'ওটিপি বা ব্যাংকিং তথ্য চাওয়া হলে সতর্ক থাকুন।',
        ],
      ),
    ],
  ),

  SafetyLesson(
    id: 'prize',
    titleEn: 'Prize & Lottery Scams',
    titleBn: 'পুরস্কার ও লটারি প্রতারণা',
    subtitleEn: 'You cannot win a contest you never entered',
    subtitleBn: 'আপনি যে প্রতিযোগিতায় অংশ নেননি তা জিততে পারেন না',
    categoryEn: 'Scams',
    categoryBn: 'প্রতারণা',
    icon: '🎁',
    minutes: 4,
    sections: [
      LessonSection(
        titleEn: 'How it works',
        titleBn: 'এটি কীভাবে কাজ করে',
        contentEn:
            'Scammers may claim that you won money or a prize '
            'and then ask for a fee before releasing it.',
        contentBn:
            'প্রতারকরা বলতে পারে যে আপনি টাকা বা পুরস্কার জিতেছেন '
            'এবং তা ছাড়ার আগে একটি ফি চাইতে পারে।',
        tipsEn: [
          'Do not send money to claim an unexpected prize.',
          'Do not share OTP or banking information.',
          'Verify the offer using an official source.',
        ],
        tipsBn: [
          'অপ্রত্যাশিত পুরস্কারের জন্য টাকা পাঠাবেন না।',
          'ওটিপি বা ব্যাংকিং তথ্য শেয়ার করবেন না।',
          'অফিসিয়াল উৎসের মাধ্যমে যাচাই করুন।',
        ],
      ),
    ],
  ),

  SafetyLesson(
    id: 'social',
    titleEn: 'Social Media Scams',
    titleBn: 'সোশ্যাল মিডিয়া প্রতারণা',
    subtitleEn: 'Stay safe on Facebook and messaging platforms',
    subtitleBn: 'ফেসবুক ও মেসেজিং প্ল্যাটফর্মে নিরাপদ থাকুন',
    categoryEn: 'Social Media',
    categoryBn: 'সোশ্যাল মিডিয়া',
    icon: '📱',
    minutes: 5,
    sections: [
      LessonSection(
        titleEn: 'Stay cautious',
        titleBn: 'সতর্ক থাকুন',
        contentEn:
            'Scammers can use fake profiles, hacked accounts, '
            'and impersonation to gain your trust.',
        contentBn:
            'প্রতারকরা ভুয়া প্রোফাইল, হ্যাক করা অ্যাকাউন্ট এবং '
            'ছদ্মবেশে আপনার বিশ্বাস অর্জন করতে পারে।',
        tipsEn: [
          'Verify unusual requests through another channel.',
          'Do not send money based only on a social media message.',
          'Avoid sharing sensitive personal information publicly.',
        ],
        tipsBn: [
          'অস্বাভাবিক অনুরোধ অন্য মাধ্যমে যাচাই করুন।',
          'শুধু সোশ্যাল মিডিয়া মেসেজের ভিত্তিতে টাকা পাঠাবেন না।',
          'সংবেদনশীল ব্যক্তিগত তথ্য প্রকাশ্যে শেয়ার এড়িয়ে চলুন।',
        ],
      ),
    ],
  ),
];