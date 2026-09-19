/// The sets that ship with the app, so there is something to do before the
/// first trip to the learner's own AI.
///
/// They are written to the same rules the learner's assistant is given, and
/// every one has been checked against them: each wrong reply contradicts a
/// fact in what was said, each wrong prediction contradicts it or asks again
/// what the reply already answered, and every wrong option says which.
///
/// The English is the same for everyone. What the learner reads — where it
/// happens, who is speaking, the summaries, the reasons, the translations —
/// is per language; a language with none of its own reads the English.
///
/// The right option is written first here, as the prompt asks of the AI; it
/// is moved, from the set's own id, when the set is built.
library;

import '../../domain/scene.dart';

/// What one language reads of a sample.
class SampleText {
  final String scene;
  final String partnerName;
  final String partnerNative;
  final String responseNative;

  /// Why the second and third replies are wrong.
  final List<String> replyWhy;

  /// The three predictions, the right one first, and why the other two are
  /// wrong.
  final List<String> predict;
  final List<String> predictWhy;

  const SampleText({
    required this.scene,
    required this.partnerName,
    this.partnerNative = '',
    this.responseNative = '',
    required this.replyWhy,
    required this.predict,
    required this.predictWhy,
  });
}

class SampleSet {
  final String id;
  final String field;
  final String partner;
  final String paraphrase;
  final List<String> partnerStress;
  final List<String> replies;
  final TurnType trap;
  final String response;
  final List<String> responseStress;
  final Map<String, SampleText> text;

  const SampleSet({
    required this.id,
    required this.field,
    required this.partner,
    required this.paraphrase,
    required this.partnerStress,
    required this.replies,
    required this.trap,
    required this.response,
    required this.responseStress,
    required this.text,
  });
}

const sampleSets = <SampleSet>[
  // ------------------------------------------------------------------ work
  SampleSet(
    id: 'sample_work_kickoff',
    field: 'work',
    partner: "Hey, quick one before you head out. The client moved tomorrow's kickoff "
        'from ten to two, and they want it at their office instead of ours, so '
        "we'll need to leave here by one. Also, could you bring the printed "
        'proposal? Not the draft from Monday, the version I sent last night with '
        "the updated pricing. I'll handle the slides.",
    paraphrase: "One quick thing before you go. Tomorrow's kickoff with the client is "
        "now at two, not ten, and it's at their office, so we leave here at one. "
        'Please print the proposal I emailed last night, the one with the new '
        "pricing, not Monday's draft. The slides are on me.",
    partnerStress: ['quick', 'head', 'client', 'moved', 'ten', 'two', 'their', 'office',
      'leave', 'one', 'printed', 'proposal', 'not', 'monday', 'last', 'night', 'pricing',
      'slides'],
    replies: [
      "Got it. Two o'clock at their office, so we leave at one. I'll print last night's version.",
      "Sure. I'll print Monday's draft and bring the slides as well.",
      "Okay, ten at our office. I'll have the proposal ready.",
    ],
    trap: TurnType.multiFact,
    response: "Thanks. Let's meet in the lobby at one, then. And please double-check "
        'the pricing page before you print it out.',
    responseStress: ['thanks', 'lobby', 'one', 'double-check', 'pricing', 'print'],
    text: {
      'en': SampleText(
        scene: 'A colleague, as you leave for the day',
        partnerName: 'Colleague',
        replyWhy: [
          'Not Monday’s draft but last night’s version, and the slides are theirs',
          'It moved from ten to two, and to the client’s office',
        ],
        predict: [
          'Thanks you, and suggests meeting in the lobby at one',
          'Asks you to print the slides as well',
          'Says the time is still ten',
        ],
        predictWhy: [
          'They said they would handle the slides themselves',
          'They said themselves it moved to two',
        ],
      ),
      'ja': SampleText(
        scene: '職場：帰り際の同僚から',
        partnerName: '同僚',
        partnerNative: 'ちょっといい、帰る前に。明日のキックオフ、先方が10時から2時に変えたんだ。'
            'それと場所もうちじゃなくて先方のオフィスだから、1時にはここを出ないと。'
            'あと、印刷した提案書を持ってきてくれる？月曜の下書きじゃなくて、昨夜送った'
            '価格を更新した版ね。スライドは僕がやるから。',
        responseNative: 'ありがとう。じゃあ1時にロビーで。あと、印刷する前に価格のページを'
            'もう一度確認してね。',
        replyWhy: [
          '月曜の下書きではなく昨夜の版。スライドは相手の担当',
          '10時→2時、場所も先方のオフィスに変わった',
        ],
        predict: [
          '礼を言って、1時にロビーで待ち合わせようと言う',
          'スライドも印刷してほしいと頼む',
          '時間は10時のままだと言い直す',
        ],
        predictWhy: [
          'スライドは自分がやると言っている',
          '2時に変更したと自分で言っている',
        ],
      ),
    },
  ),
  SampleSet(
    id: 'sample_work_room',
    field: 'work',
    partner: 'Morning. Just so you know, the big meeting room on the fourth floor is '
        "closed today because they're fixing the air conditioning. Your two o'clock "
        'with the design team has moved to the small room on the second floor. It '
        'only seats six, so if more than six people are coming, let me know by noon '
        "and I'll find somewhere else.",
    paraphrase: "Good morning. Today the large meeting room on the fourth floor can't be "
        'used, because the air conditioning is being repaired. Your meeting with the '
        'design team at two is now in the small room on floor two. That room holds '
        'six people at most, so tell me before twelve if your group is bigger, and '
        "I'll look for another room.",
    partnerStress: ['morning', 'know', 'big', 'fourth', 'closed', 'today', 'fixing', 'two',
      'design', 'moved', 'small', 'second', 'six', 'more', 'noon', 'somewhere'],
    replies: [
      "Thanks. Eight of us are coming at two, so I'm letting you know before noon.",
      "Thanks. We'll use the fourth floor room at two, there are only five of us.",
      "Thanks. Eight of us are coming, so I'll let you know this evening.",
    ],
    trap: TurnType.multiFact,
    response: "Eight, got it. That won't fit, so I'll book the training room on the "
        'third floor instead and send you the details before lunch.',
    responseStress: ['eight', "won't", 'fit', 'training', 'third', 'details', 'lunch'],
    text: {
      'en': SampleText(
        scene: 'The office manager, first thing in the morning',
        partnerName: 'Office manager',
        replyWhy: [
          'The fourth floor room is closed today',
          'You have to tell them by noon, not this evening',
        ],
        predict: [
          'Says they will book another room and send the details before lunch',
          'Asks how many people are coming',
          'Says they will book the big room on the fourth floor again',
        ],
        predictWhy: [
          'You already said eight are coming',
          'That room is closed today for repairs',
        ],
      ),
      'ja': SampleText(
        scene: '職場：朝いちばんの総務から',
        partnerName: '総務の人',
        partnerNative: 'おはようございます。念のためお伝えすると、4階の大会議室は空調の修理で'
            '今日は使えません。デザインチームとの2時の打ち合わせは2階の小会議室に移りました。'
            '6人しか入らないので、6人より多く来るなら正午までに教えてください。別の場所を'
            '探します。',
        responseNative: '8人ですね、了解です。それだと入らないので、代わりに3階の研修室を取って、'
            '昼までに詳細を送ります。',
        replyWhy: [
          '4階の大会議室は今日は使えない（空調の修理中）',
          '知らせる期限は夕方ではなく正午まで',
        ],
        predict: [
          '別の部屋を取って、昼までに詳細を送ると言う',
          '何人来るのかをもう一度聞く',
          '4階の大会議室を取り直すと言う',
        ],
        predictWhy: [
          '8人来ると、こちらがもう答えている',
          '4階の大会議室は今日は修理で使えない',
        ],
      ),
    },
  ),

  // ---------------------------------------------------------------- travel
  SampleSet(
    id: 'sample_travel_hotel',
    field: 'travel',
    partner: 'Good evening, and welcome. Your room is on the ninth floor, and breakfast '
        'is served from six thirty to ten in the restaurant on the ground floor. '
        'Checkout is at eleven, but you can keep your bags with us until five if '
        'you have a late flight. The wifi password is on the back of your key card.',
    paraphrase: "Welcome, and good evening. You're on floor nine. Breakfast is in the "
        'ground floor restaurant, from half past six until ten. You need to check '
        'out by eleven, and if your flight is late, we can hold your luggage until '
        "five. You'll find the wifi password printed on the back of the key card.",
    partnerStress: ['evening', 'welcome', 'ninth', 'breakfast', 'six', 'thirty', 'ten',
      'ground', 'checkout', 'eleven', 'bags', 'five', 'late', 'flight', 'wifi', 'password',
      'back', 'key'],
    replies: [
      'Great. We fly at eight tonight, so could we leave our bags here until five?',
      "Great. We fly late, so we'll leave our bags here until seven tonight.",
      "Great. We'll have breakfast up on the ninth floor before we check out at eleven.",
    ],
    trap: TurnType.multiFact,
    response: 'Of course. Just bring your bags down to the desk when you check out, '
        "and we'll hold them for you until five.",
    responseStress: ['course', 'bags', 'desk', 'check', 'hold', 'five'],
    text: {
      'en': SampleText(
        scene: 'Checking in at a hotel',
        partnerName: 'Front desk',
        replyWhy: [
          'They keep bags until five, not seven',
          'Breakfast is in the ground floor restaurant, not on the ninth floor',
        ],
        predict: [
          'Agrees, and says to bring the bags to the desk at checkout',
          'Asks what time your flight is',
          'Says breakfast starts at seven',
        ],
        predictWhy: [
          'You already said your flight is at eight',
          'They said breakfast starts at six thirty',
        ],
      ),
      'ja': SampleText(
        scene: 'ホテルのチェックイン',
        partnerName: 'フロント',
        partnerNative: 'こんばんは、ようこそ。お部屋は9階です。朝食は1階のレストランで6時半から'
            '10時までです。チェックアウトは11時ですが、遅い便でしたら5時までお荷物を'
            'お預かりできます。Wi-Fiのパスワードはカードキーの裏にあります。',
        responseNative: 'もちろんです。チェックアウトの際にフロントまでお荷物をお持ちください。'
            '5時までお預かりします。',
        replyWhy: [
          '荷物を預けられるのは7時ではなく5時まで',
          '朝食は9階ではなく1階のレストラン',
        ],
        predict: [
          '引き受けて、チェックアウトの時に荷物をフロントへ持ってくるよう言う',
          '何時の便かを聞く',
          '朝食は7時からだと伝える',
        ],
        predictWhy: [
          '夜8時の便だと、こちらがもう答えている',
          '朝食は6時半からと言っている',
        ],
      ),
    },
  ),
  SampleSet(
    id: 'sample_travel_gate',
    field: 'travel',
    partner: "Excuse me, are you on the flight to Singapore? It's been moved from gate "
        "twelve to gate twenty, which is about a ten minute walk. Boarding now starts "
        "at four fifteen, not four o'clock, because the plane arrived late. If you "
        "checked a bag, you don't need to do anything, it'll be moved for you.",
    paraphrase: 'Sorry to bother you. Is Singapore your flight? The gate has changed. '
        "It's now twenty, not twelve, and that's roughly ten minutes on foot. The "
        'plane came in late, so boarding begins at a quarter past four instead of '
        'four. Any checked luggage will be transferred automatically, so there is '
        'nothing for you to do.',
    partnerStress: ['excuse', 'singapore', 'moved', 'twelve', 'twenty', 'ten', 'walk',
      'boarding', 'four', 'fifteen', 'not', 'late', 'checked', 'bag', "don't", 'anything'],
    replies: [
      "Yes, that's me. Gate twenty, boarding at four fifteen. I'll start walking over now.",
      "Yes, that's me. So I just stay here at gate twelve until four fifteen.",
      "Yes, that's me. Gate twenty at four. Should I go and move my checked bag?",
    ],
    trap: TurnType.keyword,
    response: "That's right. You've got plenty of time, but the moving walkway is closed "
        'today, so allow the full ten minutes.',
    responseStress: ['right', 'plenty', 'time', 'walkway', 'closed', 'full', 'ten'],
    text: {
      'en': SampleText(
        scene: 'At the airport, before boarding',
        partnerName: 'Airline staff',
        replyWhy: [
          'The gate moved from twelve to twenty',
          'Boarding is at four fifteen, and a checked bag needs nothing from you',
        ],
        predict: [
          'Says there is plenty of time, but to allow the full ten minutes',
          'Asks which flight you are on',
          'Says the gate is still twelve',
        ],
        predictWhy: [
          'You already said you are on the Singapore flight',
          'They said it moved to gate twenty',
        ],
      ),
      'ja': SampleText(
        scene: '空港：搭乗前',
        partnerName: '航空会社の係員',
        partnerNative: 'すみません、シンガポール行きの便のお客様ですか？搭乗口が12番から20番に'
            '変わりました。歩いて10分ほどです。機体の到着が遅れたため、搭乗開始は4時ではなく'
            '4時15分です。預けたお荷物は何もしなくて大丈夫です。こちらで移します。',
        responseNative: 'そのとおりです。時間は十分ありますが、今日は動く歩道が止まっているので、'
            'たっぷり10分は見ておいてください。',
        replyWhy: [
          '搭乗口は12番から20番に変わった',
          '搭乗は4時ではなく4時15分。預けた荷物は何もしなくてよい',
        ],
        predict: [
          '時間は十分あるが、歩いて10分かかるつもりで行くよう言う',
          'どの便に乗るのかを聞く',
          '搭乗口は12番のままだと言い直す',
        ],
        predictWhy: [
          'シンガポール行きだと、こちらがもう答えている',
          '20番に変わったと自分で言っている',
        ],
      ),
    },
  ),

  // ---------------------------------------------------------------- school
  SampleSet(
    id: 'sample_school_essay',
    field: 'school',
    partner: "Before you go, a quick reminder about the essay. It's due next Friday, not "
        'this Friday, and it should be around fifteen hundred words. Please send it '
        'by email rather than handing in a paper copy. If you want me to look at a '
        'draft first, bring it to my office on Tuesday afternoon.',
    paraphrase: 'One more thing about the essay before you leave. The deadline is Friday '
        'of next week, not the Friday coming up, and the length should be about one '
        'thousand five hundred words. Submit it by email, not on paper. And if you '
        "would like feedback on a draft, come by my office on Tuesday after lunch.",
    partnerStress: ['before', 'quick', 'essay', 'due', 'next', 'friday', 'not', 'this',
      'fifteen', 'hundred', 'email', 'paper', 'draft', 'office', 'tuesday', 'afternoon'],
    replies: [
      "Thanks. I'll bring my draft on Tuesday and email the final essay by next Friday.",
      "Thanks. I'll hand in a printed copy at your office this Friday afternoon.",
      "Thanks. I'll send my draft by email on Thursday, about five hundred words.",
    ],
    trap: TurnType.polarity,
    response: 'Great. Any time after two on Tuesday is fine. Just knock on the door, '
        'and we can go through your draft together.',
    responseStress: ['great', 'after', 'two', 'tuesday', 'knock', 'door', 'draft',
      'together'],
    text: {
      'en': SampleText(
        scene: 'After class, with your teacher',
        partnerName: 'Teacher',
        replyWhy: [
          'It is due next Friday, not this one, and it goes by email, not on paper',
          'The draft is brought to the office on Tuesday, and it is about fifteen hundred words',
        ],
        predict: [
          'Says any time after two on Tuesday is fine, and you can go through the draft together',
          'Says the deadline is this Friday',
          'Asks you to hand it in on paper',
        ],
        predictWhy: [
          'They said it is due next Friday, not this one',
          'They asked for it by email',
        ],
      ),
      'ja': SampleText(
        scene: '授業のあと、先生から',
        partnerName: '先生',
        partnerNative: '帰る前に、レポートについて少しだけ。締め切りは今週ではなく来週の金曜で、'
            '長さは1500語くらい。紙で提出するのではなく、メールで送ってください。先に下書きを'
            '見てほしければ、火曜の午後に研究室へ持ってきてください。',
        responseNative: 'いいですね。火曜は2時以降ならいつでも大丈夫。ノックして入ってください。'
            '一緒に下書きを見ましょう。',
        replyWhy: [
          '締め切りは今週ではなく来週の金曜。提出は紙ではなくメール',
          '下書きは火曜の午後に研究室へ持参。字数は約1500語',
        ],
        predict: [
          '火曜の2時以降ならいつでもよく、一緒に下書きを見ると言う',
          '締め切りは今週の金曜だと言い直す',
          '紙で提出するよう頼む',
        ],
        predictWhy: [
          '締め切りは今週ではなく来週だと言っている',
          'メールで送るように言っている',
        ],
      ),
    },
  ),
  SampleSet(
    id: 'sample_school_library',
    field: 'school',
    partner: "You can borrow up to five books at a time, and they're due back in two "
        'weeks. The study rooms upstairs have to be booked online, and each booking is '
        'for two hours at most. The library closes at nine on weekdays, but on '
        "Saturdays it closes at five, and it's closed all day Sunday.",
    paraphrase: 'Five books is the most you can take out at once, and you have two weeks '
        'to return them. To use a study room upstairs, you need to reserve it on the '
        'website, for no more than two hours each time. On weekdays we are open until '
        "nine. On Saturday we close at five, and on Sunday we don't open at all.",
    partnerStress: ['borrow', 'five', 'books', 'two', 'weeks', 'study', 'upstairs',
      'online', 'hours', 'most', 'nine', 'weekdays', 'saturdays', 'closed', 'sunday'],
    replies: [
      "Thanks. I'll book a study room online for Saturday from two until four.",
      'Thanks. Can I book a study room here at the desk for Sunday morning?',
      "Thanks. I'll book a study room online for Saturday from four until seven.",
    ],
    trap: TurnType.multiFact,
    response: 'Sounds good. Use the library website, and remember to bring your student '
        'card, because the rooms are locked without it.',
    responseStress: ['good', 'website', 'remember', 'student', 'card', 'locked',
      'without'],
    text: {
      'en': SampleText(
        scene: 'At the university library desk',
        partnerName: 'Librarian',
        replyWhy: [
          'Rooms are booked online, and the library is closed on Sunday',
          'It closes at five on Saturday, and a booking is two hours at most',
        ],
        predict: [
          'Says to use the library website, and to bring your student card',
          'Says the library is open until nine on Saturday',
          'Asks what time you want the room',
        ],
        predictWhy: [
          'They said it closes at five on Saturday',
          'You already said two until four',
        ],
      ),
      'ja': SampleText(
        scene: '大学図書館のカウンター',
        partnerName: '図書館の職員',
        partnerNative: '本は一度に5冊まで借りられて、返却は2週間後です。上の階の自習室は'
            'オンラインでの予約が必要で、1回の予約は最長2時間です。閉館は平日が9時、'
            '土曜は5時で、日曜は終日休館です。',
        responseNative: 'いいですね。図書館のサイトから予約してください。それと学生証を忘れずに。'
            'ないと部屋の鍵が開きません。',
        replyWhy: [
          '予約はオンラインのみ。日曜は終日休館',
          '土曜は5時に閉館。予約は1回最長2時間',
        ],
        predict: [
          '図書館のサイトから予約するよう言い、学生証を持ってくるよう念を押す',
          '土曜は9時まで開いていると言う',
          '何時から使いたいかを聞き返す',
        ],
        predictWhy: [
          '土曜は5時に閉館すると言っている',
          '2時から4時と、こちらがもう答えている',
        ],
      ),
    },
  ),

  // ----------------------------------------------------------------- daily
  SampleSet(
    id: 'sample_daily_restaurant',
    field: 'daily',
    partner: "Hi there, welcome to Bella's. So, we're pretty busy tonight. Without a "
        "reservation it's about a twenty-minute wait, but if you'd like, you can wait "
        'at the bar, and drinks there are half price until seven. Just give me a name '
        "and how many are in your party, and I'll come find you when your table's ready.",
    paraphrase: "Welcome to Bella's. It's busy tonight. With no reservation, the wait is "
        "around twenty minutes. You're welcome to wait at the bar, where drinks are "
        'half price before seven. Tell me your name and the size of your group, and '
        "I'll come get you when the table is ready.",
    partnerStress: ['welcome', "bella's", 'busy', 'without', 'reservation', 'twenty',
      'wait', 'bar', 'half', 'seven', 'name', 'many', 'party', 'find', 'ready'],
    replies: [
      "No reservation. It's Tanaka, two people. We'll wait at the bar.",
      "We have a reservation under Tanaka, so we'll wait at the bar for twenty minutes.",
      "Tanaka, party of two. We'll grab the free drinks at the bar while we wait.",
    ],
    trap: TurnType.multiFact,
    response: "Perfect. Tanaka, party of two. Head on over to the bar, and I'll come get "
        'you in about twenty minutes.',
    responseStress: ['perfect', 'tanaka', 'two', 'bar', 'get', 'twenty'],
    text: {
      'en': SampleText(
        scene: 'At the door of a restaurant',
        partnerName: 'Host',
        replyWhy: [
          'The twenty minute wait is for people without a reservation',
          'The drinks are half price, not free',
        ],
        predict: [
          'Confirms the name and number, and says they will come and get you',
          'Asks again whether you have a reservation',
          'Takes you to a table right away',
        ],
        predictWhy: [
          'You already said you have no reservation',
          'They said there is a twenty minute wait',
        ],
      ),
      'ja': SampleText(
        scene: 'レストランの受付',
        partnerName: '受付',
        partnerNative: 'こんばんは、ベラズへようこそ。今夜はかなり混んでいまして、ご予約がないと'
            '20分ほどお待ちいただきます。よろしければバーでお待ちいただけます。バーの'
            'お飲み物は7時まで半額です。お名前と人数をお伺いできれば、お席の用意ができ次第'
            'お呼びします。',
        responseNative: 'かしこまりました。田中様、2名様ですね。バーのほうへどうぞ。20分ほどで'
            'お呼びします。',
        replyWhy: [
          '予約があれば20分待ちではない（待つのは予約なしの場合）',
          '無料ではなく半額（half price）',
        ],
        predict: [
          '名前と人数を確認して、席が空いたら呼びに来ると言う',
          '予約があるかどうかをもう一度聞く',
          '今すぐ席に案内する',
        ],
        predictWhy: [
          '予約なしだと、こちらがもう答えている',
          '20分待ちと言っているので、今すぐは矛盾',
        ],
      ),
    },
  ),
  SampleSet(
    id: 'sample_daily_water',
    field: 'daily',
    partner: "Hi, I'm from the building office. The water will be turned off tomorrow "
        'from nine in the morning until one in the afternoon for repairs. Please '
        "don't use the washing machine during that time. The elevator will still "
        'work, but the parking garage will be closed until three, so move your car '
        'out before nine if you need it.',
    paraphrase: 'Hello, this is the building office. Tomorrow there will be no water '
        "between nine a.m. and one p.m. while repairs are done, so please don't run "
        "your washing machine then. The elevator won't be affected. The parking "
        "garage, though, stays shut until three, so take your car out before nine if "
        "you'll be using it.",
    partnerStress: ['building', 'office', 'water', 'off', 'tomorrow', 'nine', 'morning',
      'one', 'afternoon', 'repairs', "don't", 'washing', 'elevator', 'still', 'parking',
      'closed', 'three', 'car', 'before'],
    replies: [
      "Thanks for telling me. I'll move my car out tonight and do laundry after one.",
      "Thanks for telling me. I'll run the washing machine at ten, while I'm home.",
      "Thanks for telling me. The elevator's off too, so I'll take the stairs tomorrow.",
    ],
    trap: TurnType.polarity,
    response: 'Thank you. Everything should be back to normal by one, and I will put a '
        'note in the elevator if the work runs late.',
    responseStress: ['thank', 'normal', 'one', 'note', 'elevator', 'late'],
    text: {
      'en': SampleText(
        scene: 'At your door, from the building office',
        partnerName: 'Building office',
        replyWhy: [
          'The water is off from nine until one, so no washing machine at ten',
          'The elevator will still work',
        ],
        predict: [
          'Says it should be back to normal by one, with a note in the elevator if it runs late',
          'Says the elevator will be off too',
          'Asks whether you have a car',
        ],
        predictWhy: [
          'They said the elevator will still work',
          'You already said you will move your car',
        ],
      ),
      'ja': SampleText(
        scene: '自宅の玄関先：管理事務所から',
        partnerName: '管理事務所の人',
        partnerNative: 'こんにちは、管理事務所の者です。明日は修理のため、朝9時から午後1時まで'
            '断水します。その間は洗濯機を使わないでください。エレベーターは動きますが、'
            '駐車場は3時まで閉鎖なので、車を使うなら9時より前に出しておいてください。',
        responseNative: 'ありがとうございます。1時にはすべて元に戻るはずです。工事が延びたら'
            'エレベーターに貼り紙をしておきます。',
        replyWhy: [
          '9時から1時までは断水するので、10時に洗濯機は使えない',
          'エレベーターは止まらず動く',
        ],
        predict: [
          '1時には元に戻るはずで、延びたらエレベーターに貼り紙をすると言う',
          'エレベーターも止まると言い直す',
          '車を持っているかを聞く',
        ],
        predictWhy: [
          'エレベーターは動くと言っている',
          '車を出しておくと、こちらがもう答えている',
        ],
      ),
    },
  ),
];
