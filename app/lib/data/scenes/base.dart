/// The English of every conversation that ships with the app.
///
/// These are samples, and they are meant to be outgrown: the tree grows
/// leaves on them but never flowers. They exist so that the app has something
/// to do before the first trip to the learner's own AI, and so that the four
/// sample fields are not four empty rooms.
///
/// They are written to the same rules the learner's assistant is given, and
/// the rules are not decoration. Every turn here has been put through them:
///
/// - **Hide the line.** Given only the setting and the three replies, nobody
///   can tell which is right. A reply that gives itself away turns listening
///   practice into reading practice.
/// - **A `keyword` pair must sound alike, and only one of the two may be in
///   the line.** Swap the pair in and the line must still be a grammatical
///   sentence the same person could have said — otherwise the wrong reply is
///   ruled out without hearing anything.
/// - **A `polarity` turn keeps one wrong reply for the person who missed the
///   reversing word.** That is what makes a wrong answer worth something.
/// - **A `multiFact` turn's wrong replies each drop exactly one fact, and say
///   which.**
///
/// Translations live per language in `overlay_*.dart`. A language with no
/// overlay still plays: the English is all here, and only the glosses are
/// missing — which is where the translation rung of the ladder ends up
/// anyway.
library;

import '../../domain/scene.dart';

/// The right reply is written first in every turn below, as the prompt asks
/// of the learner's assistant. [_scene] moves it, deterministically, from the
/// conversation's own id — so an author never has to think about position and
/// every language agrees on where it landed.
Scene _scene({
  required String id,
  required String field,
  required String situation,
  required String title,
  required int windowMs,
  required List<Turn> turns,
}) =>
    Scene(
      id: id,
      title: title,
      situation: situation,
      windowMs: windowMs,
      turns: [
        for (var i = 0; i < turns.length; i++)
          _arrange(turns[i], optionOrder(id, i)),
      ],
      source: SceneSource.builtin,
      realmId: field,
      createdAt: 0,
    );

Turn _arrange(Turn t, List<int> order) => Turn(
      type: t.type,
      line: t.line,
      keyWord: t.keyWord,
      confusable: t.confusable,
      facts: t.facts,
      replies: arrangeBy(order, t.replies),
      restate: t.restate,
    );

/// One turn. [replies] is right-first; the rest are what a mishearing would
/// pick.
Turn _turn({
  TurnType type = TurnType.keyword,
  required String line,
  String keyWord = '',
  String confusable = '',
  List<Fact> facts = const [],
  required List<Reply> replies,
  required String restate,
}) =>
    Turn(
      type: type,
      line: line,
      keyWord: keyWord,
      confusable: confusable,
      facts: facts,
      replies: replies,
      restate: restate,
    );

Reply _ok(String text) => Reply(text: text, correct: true);
Reply _no(String text, {String? missed}) => Reply(text: text, missedSlot: missed);

// --------------------------------------------------------------------- work

final _work = <Scene>[
  _scene(
    id: 'builtin_w1',
    field: 'work',
    situation: 'a deadline',
    title: 'Moving a deadline',
    windowMs: 3000,
    turns: [
      _turn(
        line: "The handover's on Thursday, so I'll need the file the night before.",
        keyWord: 'Thursday',
        confusable: 'Tuesday',
        replies: [
          _ok("Thursday — I'll have it ready the evening before."),
          _no("Tuesday, got it. I'll finish it off over the weekend."),
          _no("Is there any chance of another day? That week is full."),
        ],
        restate: "It's the Thursday handover, so the file has to be in the night before.",
      ),
      _turn(
        type: TurnType.polarity,
        line: "I won't get to it before Wednesday unless my morning clears.",
        keyWord: 'unless',
        confusable: 'if',
        replies: [
          _ok("Understood — only if your morning frees up, then."),
          _no("Good, so it'll be with me by Wednesday morning."),
          _no("Would it help if I took part of it off you?"),
        ],
        restate: "Only a clear morning would let me start it before Wednesday.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_w2',
    field: 'work',
    situation: 'a call',
    title: 'A call that moved',
    windowMs: 2000,
    turns: [
      _turn(
        line: "The review call's been pushed back fifteen minutes.",
        keyWord: 'fifteen',
        confusable: 'fifty',
        replies: [
          _ok("A quarter of an hour — fine, I'll dial in later."),
          _no("Fifty? That puts us right into lunch."),
          _no("Has everyone been told, or shall I pass it on?"),
        ],
        restate: "It starts a quarter of an hour later than it says in the invite.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_w3',
    field: 'work',
    situation: 'cover',
    title: 'Who is covering',
    windowMs: 3000,
    turns: [
      _turn(
        type: TurnType.multiFact,
        line: "The person covering the desk starts at nine, on the second floor.",
        facts: [
          Fact(slot: 'time', value: 'nine', confusable: 'ten'),
          Fact(slot: 'place', value: 'the second floor', confusable: 'the third floor'),
        ],
        replies: [
          _ok("Nine, second floor. I'll let them know."),
          _no("Ten on the second floor — I'll pass that on.", missed: 'time'),
          _no("Nine, up on the third floor. Got it.", missed: 'place'),
        ],
        restate: "Second floor, and they're in from nine.",
      ),
      _turn(
        line: "Ask them for the sheet before you go up.",
        keyWord: 'sheet',
        confusable: 'seat',
        replies: [
          _ok("Will do — I'll pick the paperwork up on the way."),
          _no("A seat? I can stand, it's not a long meeting."),
          _no("Is that something they hand out, or do I ask?"),
        ],
        restate: "Get the printed one off them before you head upstairs.",
      ),
      _turn(
        type: TurnType.polarity,
        line: "Don't wait for me if the room's already open.",
        keyWord: "don't",
        confusable: 'do',
        replies: [
          _ok("Sure — if it's open I'll go straight in."),
          _no("Right, I'll hang on outside for you either way."),
          _no("Shall I text you when I get there?"),
        ],
        restate: "An open room means go in; there's no need to stand about for me.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_w4',
    field: 'work',
    situation: 'a request',
    title: 'A favour before lunch',
    windowMs: 2000,
    turns: [
      _turn(
        line: "Could you look at this before the launch?",
        keyWord: 'launch',
        confusable: 'lunch',
        replies: [
          _ok("Before it goes live — yes, I'll make time today."),
          _no("Before lunch is tight, but I can manage a quick look."),
          _no("How long do you think it needs from me?"),
        ],
        restate: "It needs a pair of eyes on it before the thing goes out.",
      ),
      _turn(
        line: "There's a copy on the desk if you'd rather read it on paper.",
        keyWord: 'copy',
        confusable: 'coffee',
        replies: [
          _ok("A printout — that's easier, thanks. I'll grab it."),
          _no("Coffee would be lovely, actually. Thank you."),
          _no("I'll read it on screen, it's quicker for me."),
        ],
        restate: "There's a printed one sitting out, if paper suits you better.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_w5',
    field: 'work',
    situation: 'a change of plan',
    title: 'The visit is off',
    windowMs: 4000,
    turns: [
      _turn(
        type: TurnType.polarity,
        line: "They're not coming in on Friday after all.",
        keyWord: 'not',
        confusable: '',
        replies: [
          _ok("So Friday's clear again. I'll take the room booking down."),
          _no("Friday it is — I'll get the room set up."),
          _no("Do we know yet who's coming with them?"),
        ],
        restate: "Friday's visit has fallen through; nobody's coming.",
      ),
      _turn(
        line: "We'll do it on the thirteenth instead.",
        keyWord: 'thirteenth',
        confusable: 'thirtieth',
        replies: [
          _ok("The thirteenth — that's the week after next, isn't it?"),
          _no("The thirtieth. That's nearly a month away."),
          _no("Is that fixed, or might it move again?"),
        ],
        restate: "It's been moved to the one after the twelfth.",
      ),
      _turn(
        type: TurnType.multiFact,
        line: "Book the small room for two hours, from four.",
        facts: [
          Fact(slot: 'length', value: 'two hours', confusable: 'an hour'),
          Fact(slot: 'time', value: 'four', confusable: 'five'),
        ],
        replies: [
          _ok("Two hours from four. I'll put it in now."),
          _no("An hour from four — booked.", missed: 'length'),
          _no("Two hours from five, then.", missed: 'time'),
        ],
        restate: "From four, and hold it for a couple of hours.",
      ),
      _turn(
        line: "Let the team know, and copy in whoever takes the notes.",
        keyWord: 'notes',
        confusable: 'notice',
        replies: [
          _ok("I'll tell everyone and add the person writing things up."),
          _no("I'll send it out and give them plenty of notice."),
          _no("Shall I put it in the team channel or send it round?"),
        ],
        restate: "Tell the team, and put the person minuting it on there too.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_w6',
    field: 'work',
    situation: 'a corridor',
    title: 'Caught in the corridor',
    windowMs: 2000,
    turns: [
      _turn(
        line: "I'll walk over after this and look at it with you.",
        keyWord: 'walk',
        confusable: 'work',
        replies: [
          _ok("Come over whenever — I'll be at my desk."),
          _no("If you'd rather work on it from there, that's fine too."),
          _no("Great. Give me ten minutes to get it open."),
        ],
        restate: "I'll come across to you once this is done, and we'll look together.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_w7',
    field: 'work',
    situation: 'a report',
    title: 'One more pass',
    windowMs: 3000,
    turns: [
      _turn(
        line: "The last part still needs a bit of work.",
        keyWord: 'work',
        confusable: 'walk',
        replies: [
          _ok("I'll go back over the ending and tidy it up."),
          _no("A walk might help, actually — I've been staring at it."),
          _no("Is it the wording, or is something missing?"),
        ],
        restate: "The ending isn't finished; it wants another pass.",
      ),
      _turn(
        type: TurnType.polarity,
        line: "I can hardly read the numbers in that table.",
        keyWord: 'hardly',
        confusable: '',
        replies: [
          _ok("I'll make the figures bigger and give it more room."),
          _no("Good — I thought the table came out clearly."),
          _no("Would a chart work better than a table there?"),
        ],
        restate: "Those figures are almost impossible to make out.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_w8',
    field: 'work',
    situation: 'a handover',
    title: 'Leaving it with someone',
    windowMs: 3000,
    turns: [
      _turn(
        line: "Leave it with the person on the front desk.",
        keyWord: 'leave',
        confusable: 'live',
        replies: [
          _ok("I'll drop it off downstairs on my way out."),
          _no("They live near there, don't they? That's handy."),
          _no("Does it need signing for, or can I just hand it over?"),
        ],
        restate: "Hand it in downstairs and they'll keep hold of it.",
      ),
      _turn(
        line: "I'll be back at half past ten.",
        keyWord: 'ten',
        confusable: 'two',
        replies: [
          _ok("Half ten — I'll catch you in the morning, then."),
          _no("Half two. I'll come by after lunch."),
          _no("Shall I leave it on your desk in the meantime?"),
        ],
        restate: "I'm back in about half an hour past the hour, in the morning.",
      ),
      _turn(
        type: TurnType.multiFact,
        line: "Send it to the team channel, not by email, and mark it urgent.",
        facts: [
          Fact(slot: 'channel', value: 'the team channel', confusable: 'email'),
          Fact(slot: 'mark', value: 'urgent', confusable: 'normal'),
        ],
        replies: [
          _ok("Team channel, flagged urgent. Doing it now."),
          _no("I'll email it and flag it urgent.", missed: 'channel'),
          _no("Team channel it is — I'll send it as normal.", missed: 'mark'),
        ],
        restate: "Post it where the team can see it, and put the urgent flag on.",
      ),
    ],
  ),
];

// ------------------------------------------------------------------- travel

final _travel = <Scene>[
  _scene(
    id: 'builtin_t1',
    field: 'travel',
    situation: 'a station',
    title: 'Which platform',
    windowMs: 2000,
    turns: [
      _turn(
        line: "It goes from platform fourteen.",
        keyWord: 'fourteen',
        confusable: 'forty',
        replies: [
          _ok("Fourteen — is that up the stairs or along here?"),
          _no("Forty? This station must be bigger than it looks."),
          _no("Thanks. Do I need to be there early?"),
        ],
        restate: "It leaves from the one after thirteen.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_t2',
    field: 'travel',
    situation: 'a hotel',
    title: 'Checking in early',
    windowMs: 3000,
    turns: [
      _turn(
        type: TurnType.polarity,
        line: "The room won't be ready until two.",
        keyWord: "won't",
        confusable: 'will',
        replies: [
          _ok("That's fine — could I leave my bag here until then?"),
          _no("Wonderful, I'll go straight up and drop my things."),
          _no("Is there somewhere nearby you'd recommend for lunch?"),
        ],
        restate: "Two o'clock is the earliest anyone can go up.",
      ),
      _turn(
        line: "Breakfast is served until half past nine.",
        keyWord: 'nine',
        confusable: 'five',
        replies: [
          _ok("Half nine — I'll come down before then."),
          _no("Half five? That's earlier than I usually manage."),
          _no("Is it in this room, or somewhere else in the building?"),
        ],
        restate: "They stop serving breakfast half an hour after nine.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_t3',
    field: 'travel',
    situation: 'directions',
    title: 'Finding the way back',
    windowMs: 3000,
    turns: [
      _turn(
        type: TurnType.multiFact,
        line: "Take the second turning and it's on your left.",
        facts: [
          Fact(slot: 'turning', value: 'the second', confusable: 'the third'),
          Fact(slot: 'side', value: 'left', confusable: 'right'),
        ],
        replies: [
          _ok("Second turning, left-hand side. Thank you."),
          _no("Third turning, then left. Got it.", missed: 'turning'),
          _no("Second turning and it's on the right.", missed: 'side'),
        ],
        restate: "Not the first one — the next after that, and look to your left.",
      ),
      _turn(
        line: "You can walk it in about ten minutes.",
        keyWord: 'walk',
        confusable: 'work',
        replies: [
          _ok("Ten minutes on foot — that's easy enough."),
          _no("I could work for ten minutes while I wait, I suppose."),
          _no("Is there a bus, or is walking the quickest?"),
        ],
        restate: "On foot it's only about ten minutes from here.",
      ),
      _turn(
        line: "There's a card machine by the door.",
        keyWord: 'card',
        confusable: 'cart',
        replies: [
          _ok("So I can pay by card. That's a relief."),
          _no("A cart by the door? I'll watch out for it."),
          _no("Does it take the small notes as well?"),
        ],
        restate: "You can pay with a card — the machine's just inside.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_t4',
    field: 'travel',
    situation: 'a booking',
    title: 'A change on the booking',
    windowMs: 3000,
    turns: [
      _turn(
        line: "We've put you in a quiet room at the back.",
        keyWord: 'quiet',
        confusable: 'quite',
        replies: [
          _ok("Away from the noise — that's very kind, thank you."),
          _no("Quite a room, is it? I'm looking forward to seeing it."),
          _no("Does it look out over the street, or the other way?"),
        ],
        restate: "It's round the back, so you shouldn't hear much.",
      ),
      _turn(
        type: TurnType.polarity,
        line: "There's no charge for changing it.",
        keyWord: 'no',
        confusable: '',
        replies: [
          _ok("Nothing to pay — that's good of you."),
          _no("How much is it? I'll pay it now while I'm here."),
          _no("And can I change it again later if I need to?"),
        ],
        restate: "Moving the booking costs you nothing at all.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_t5',
    field: 'travel',
    situation: 'a shop',
    title: 'Paying at the counter',
    windowMs: 2000,
    turns: [
      _turn(
        line: "That'll be thirteen altogether.",
        keyWord: 'thirteen',
        confusable: 'thirty',
        replies: [
          _ok("Thirteen — here you are."),
          _no("Thirty? That's more than I expected."),
          _no("Can I pay part of it by card?"),
        ],
        restate: "It comes to one more than a dozen.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_t6',
    field: 'travel',
    situation: 'a platform',
    title: 'The train is late',
    windowMs: 2000,
    turns: [
      _turn(
        type: TurnType.polarity,
        line: "It's not stopping here today.",
        keyWord: 'not',
        confusable: '',
        replies: [
          _ok("So I'll need another one. Which should I take?"),
          _no("Good — I'll wait on this platform, then."),
          _no("Is that just today, or all week?"),
        ],
        restate: "That train goes straight through; it won't pull in here.",
      ),
      _turn(
        line: "The next one's in eighteen minutes.",
        keyWord: 'eighteen',
        confusable: 'eighty',
        replies: [
          _ok("Under twenty minutes — I'll wait for that one."),
          _no("Eighty minutes? I'd better find somewhere to sit."),
          _no("Does that one stop here, at least?"),
        ],
        restate: "There's another due in a little under twenty minutes.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_t7',
    field: 'travel',
    situation: 'an airport',
    title: 'At the desk',
    windowMs: 4000,
    turns: [
      _turn(
        type: TurnType.multiFact,
        line: "Go to gate twelve, and boarding starts at quarter past.",
        facts: [
          Fact(slot: 'gate', value: 'twelve', confusable: 'twenty'),
          Fact(slot: 'time', value: 'quarter past', confusable: 'half past'),
        ],
        replies: [
          _ok("Gate twelve, boarding at quarter past. Thank you."),
          _no("Gate twenty, from quarter past.", missed: 'gate'),
          _no("Gate twelve, and they start at half past.", missed: 'time'),
        ],
        restate: "It's the gate after eleven, and they'll start fifteen minutes into the hour.",
      ),
      _turn(
        line: "You'll need to take the bag off the cart first.",
        keyWord: 'cart',
        confusable: 'card',
        replies: [
          _ok("I'll lift it off the trolley — one moment."),
          _no("My card? Of course, it's here somewhere."),
          _no("Is it too heavy, or is it the size?"),
        ],
        restate: "Lift it off the trolley before we weigh it.",
      ),
      _turn(
        type: TurnType.polarity,
        line: "You can't take that through without a label on it.",
        keyWord: "can't",
        confusable: 'can',
        replies: [
          _ok("Could I have a label, then? I'll write it out now."),
          _no("That's good news — I'll carry it through as it is."),
          _no("What usually goes on the label?"),
        ],
        restate: "Nothing goes through unlabelled, so it needs one first.",
      ),
      _turn(
        line: "Boarding's from the desk on the left.",
        keyWord: 'left',
        confusable: 'lift',
        replies: [
          _ok("The desk on that side — thank you."),
          _no("By the lift? I'll go and look for it."),
          _no("Should I go over now, or wait to be called?"),
        ],
        restate: "It's the desk on the same side as your left hand.",
      ),
    ],
  ),
];

// ------------------------------------------------------------------- school

final _school = <Scene>[
  _scene(
    id: 'builtin_s1',
    field: 'school',
    situation: 'a class',
    title: 'When the test is',
    windowMs: 3000,
    turns: [
      _turn(
        line: "The test is on Tuesday, so use the weekend.",
        keyWord: 'Tuesday',
        confusable: 'Thursday',
        replies: [
          _ok("Tuesday — I'll get most of it done on Sunday, then."),
          _no("Thursday gives me a bit more room. That helps."),
          _no("How much of the term does it cover?"),
        ],
        restate: "It's the day after Monday, so the weekend is your time.",
      ),
      _turn(
        type: TurnType.polarity,
        line: "You won't need the book for it.",
        keyWord: "won't",
        confusable: 'will',
        replies: [
          _ok("So I can leave it at home. Good."),
          _no("I'll bring it along, then — mine's at home."),
          _no("Is there anything we should bring?"),
        ],
        restate: "Leave the book behind; it isn't used in this one.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_s2',
    field: 'school',
    situation: 'a corridor',
    title: 'A quick question',
    windowMs: 2000,
    turns: [
      _turn(
        line: "Have a look at the text before next week.",
        keyWord: 'text',
        confusable: 'test',
        replies: [
          _ok("I'll read through it over the weekend."),
          _no("Is the test next week? Nobody told us."),
          _no("How long is it, roughly?"),
        ],
        restate: "Read the piece through before we meet again.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_s3',
    field: 'school',
    situation: 'a project',
    title: 'Splitting the work',
    windowMs: 3000,
    turns: [
      _turn(
        type: TurnType.multiFact,
        line: "You take the first part, and hand it in by Monday.",
        facts: [
          Fact(slot: 'part', value: 'the first part', confusable: 'the second part'),
          Fact(slot: 'day', value: 'Monday', confusable: 'Friday'),
        ],
        replies: [
          _ok("First part, in by Monday. That works."),
          _no("Second part, by Monday. Fine.", missed: 'part'),
          _no("The first part, in by Friday, then.", missed: 'day'),
        ],
        restate: "The opening section is yours, and it's due at the start of the week.",
      ),
      _turn(
        line: "Send it to me and I'll accept it either way.",
        keyWord: 'accept',
        confusable: 'except',
        replies: [
          _ok("So you'll take it however it comes. That's a relief."),
          _no("Except what? Is there a part I should leave out?"),
          _no("Shall I send the whole thing, or just my bit?"),
        ],
        restate: "However you send it, I'll take it.",
      ),
      _turn(
        type: TurnType.polarity,
        line: "I'd rather you didn't start the second half yet.",
        keyWord: "didn't",
        confusable: 'did',
        replies: [
          _ok("I'll leave it for now and wait to hear from you."),
          _no("I'll make a start on it this evening, then."),
          _no("Is something changing in that section?"),
        ],
        restate: "Hold off on the second half until I say.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_s4',
    field: 'school',
    situation: 'a room',
    title: 'Where it is held',
    windowMs: 3000,
    turns: [
      _turn(
        line: "It's in room thirty this week.",
        keyWord: 'thirty',
        confusable: 'thirteen',
        replies: [
          _ok("Room thirty — is that the one at the end?"),
          _no("Thirteen. That's the small one downstairs, isn't it?"),
          _no("Just this week, or from now on?"),
        ],
        restate: "It's the room numbered three tens.",
      ),
      _turn(
        line: "Take a seat near the front if you can.",
        keyWord: 'seat',
        confusable: 'sheet',
        replies: [
          _ok("I'll sit nearer the front this time."),
          _no("A sheet? I don't think I was given one."),
          _no("Does it matter much where we sit?"),
        ],
        restate: "Sit somewhere close to the front if there's room.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_s5',
    field: 'school',
    situation: 'a form',
    title: 'Filling it in',
    windowMs: 3000,
    turns: [
      _turn(
        line: "You'll need to confirm it before Friday.",
        keyWord: 'confirm',
        confusable: 'conform',
        replies: [
          _ok("I'll say yes to it before the end of the week."),
          _no("I'll make sure mine matches the others, then."),
          _no("Where do I do that — online, or in person?"),
        ],
        restate: "Say yes to it in writing, and do it before Friday.",
      ),
      _turn(
        type: TurnType.polarity,
        line: "It's not open on Thursdays.",
        keyWord: 'not',
        confusable: '',
        replies: [
          _ok("I'll go on another day, then."),
          _no("Thursday suits me. I'll go after class."),
          _no("What are the usual hours?"),
        ],
        restate: "Thursday is the one day it stays shut.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_s6',
    field: 'school',
    situation: 'a library',
    title: 'Taking it out',
    windowMs: 2000,
    turns: [
      _turn(
        line: "You can keep it for fourteen days.",
        keyWord: 'fourteen',
        confusable: 'forty',
        replies: [
          _ok("Two weeks — that should be plenty."),
          _no("Forty days? That's more than I'll need."),
          _no("Can I take it out again after that?"),
        ],
        restate: "It's yours for two weeks before it comes back.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_s7',
    field: 'school',
    situation: 'feedback',
    title: 'Going over the marks',
    windowMs: 4000,
    turns: [
      _turn(
        line: "Your last piece was much better than the first.",
        keyWord: 'first',
        confusable: 'worst',
        replies: [
          _ok("So I've come on since the start. That's good to hear."),
          _no("Better than my worst — I'll take that, I suppose."),
          _no("What made the difference, do you think?"),
        ],
        restate: "Compared with the one you handed in at the beginning, it's come a long way.",
      ),
      _turn(
        type: TurnType.multiFact,
        line: "Come and see me on Wednesday, in the office on the ground floor.",
        facts: [
          Fact(slot: 'day', value: 'Wednesday', confusable: 'Tuesday'),
          Fact(slot: 'place', value: 'the ground floor', confusable: 'the first floor'),
        ],
        replies: [
          _ok("Wednesday, ground floor office. I'll be there."),
          _no("Tuesday, on the ground floor. Noted.", missed: 'day'),
          _no("Wednesday, first floor office, then.", missed: 'place'),
        ],
        restate: "Midweek, and it's the office downstairs rather than up.",
      ),
      _turn(
        type: TurnType.polarity,
        line: "Don't rewrite the whole thing.",
        keyWord: "don't",
        confusable: 'do',
        replies: [
          _ok("I'll just work on the parts you marked, then."),
          _no("I'll start again from the beginning this week."),
          _no("Which parts should I look at first?"),
        ],
        restate: "There's no need to start it again — leave most of it as it is.",
      ),
    ],
  ),
];

// -------------------------------------------------------------------- daily

final _daily = <Scene>[
  _scene(
    id: 'builtin_d1',
    field: 'daily',
    situation: 'a doorstep',
    title: 'A parcel',
    windowMs: 2000,
    turns: [
      _turn(
        line: "I've left it with the neighbour at forty.",
        keyWord: 'forty',
        confusable: 'fourteen',
        replies: [
          _ok("Number forty — I'll knock on my way past."),
          _no("Fourteen? That's right down the other end."),
          _no("Did they say when they'd be in?"),
        ],
        restate: "It's next door but one, at the four-tens house.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_d2',
    field: 'daily',
    situation: 'a café',
    title: 'Ordering something',
    windowMs: 2000,
    turns: [
      _turn(
        line: "The dessert comes with it.",
        keyWord: 'dessert',
        confusable: 'desert',
        replies: [
          _ok("Something sweet as well? That's good value."),
          _no("The desert one — is that the spicy dish?"),
          _no("Could I have that without, and pay less?"),
        ],
        restate: "The sweet course is included in the price.",
      ),
      _turn(
        type: TurnType.polarity,
        line: "We can't do it without the card.",
        keyWord: 'without',
        confusable: 'with',
        replies: [
          _ok("I'll find the card — one second."),
          _no("Good, because I've left mine at home."),
          _no("Does a photo of it count?"),
        ],
        restate: "The card has to be here or it can't be done.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_d3',
    field: 'daily',
    situation: 'a phone call',
    title: 'A visit this evening',
    windowMs: 3000,
    turns: [
      _turn(
        type: TurnType.multiFact,
        line: "I'll come round at seven, and I'll bring the dog.",
        facts: [
          Fact(slot: 'time', value: 'seven', confusable: 'eleven'),
          Fact(slot: 'who', value: 'the dog', confusable: 'the children'),
        ],
        replies: [
          _ok("Seven, and the dog's welcome. See you then."),
          _no("Eleven with the dog — that's late, but fine.", missed: 'time'),
          _no("Seven, and bring the children along.", missed: 'who'),
        ],
        restate: "I'll be there at seven, and the dog's coming too.",
      ),
      _turn(
        line: "Don't worry about food, we've eaten.",
        keyWord: 'eaten',
        confusable: 'eating',
        replies: [
          _ok("Nothing to cook, then. I'll put the kettle on instead."),
          _no("You're still eating? Take your time, there's no rush."),
          _no("Are you sure? It's no trouble at all."),
        ],
        restate: "We've already had ours, so there's no need to make anything.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_d4',
    field: 'daily',
    situation: 'a repair',
    title: 'Getting it fixed',
    windowMs: 4000,
    turns: [
      _turn(
        line: "Someone can come out on the fifteenth.",
        keyWord: 'fifteenth',
        confusable: 'fiftieth',
        replies: [
          _ok("The fifteenth — that's the middle of the month, isn't it?"),
          _no("The fiftieth? There aren't that many days in a month."),
          _no("Is there anything earlier?"),
        ],
        restate: "It's the day after the fourteenth.",
      ),
      _turn(
        type: TurnType.polarity,
        line: "You don't have to be in for it.",
        keyWord: "don't",
        confusable: 'do',
        replies: [
          _ok("So I can leave the key next door and go to work."),
          _no("I'll take the morning off, then, to be here."),
          _no("How will they get in?"),
        ],
        restate: "Nobody needs to be home while they do it.",
      ),
      _turn(
        line: "There's a form to sign when it's done.",
        keyWord: 'form',
        confusable: 'phone',
        replies: [
          _ok("A bit of paperwork at the end — that's fine."),
          _no("A phone call afterwards? I'll keep mine on me."),
          _no("Does it get left with me, or do they take it?"),
        ],
        restate: "They leave a sheet to put your name on once they've finished.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_d5',
    field: 'daily',
    situation: 'a neighbour',
    title: 'Over the fence',
    windowMs: 2000,
    turns: [
      _turn(
        line: "I'll be away for a week from Sunday.",
        keyWord: 'Sunday',
        confusable: 'Monday',
        replies: [
          _ok("From Sunday — I'll keep an eye on the place."),
          _no("Monday. So you've got the weekend at home first."),
          _no("Anywhere nice, or is it work?"),
        ],
        restate: "It starts on the last day of the week and runs seven days.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_d6',
    field: 'daily',
    situation: 'a queue',
    title: 'At the counter',
    windowMs: 2000,
    turns: [
      _turn(
        type: TurnType.polarity,
        line: "This one's never busy in the morning.",
        keyWord: 'never',
        confusable: 'always',
        replies: [
          _ok("I'll come earlier next time, then."),
          _no("So mornings are the worst? I'll avoid them."),
          _no("What about later in the day?"),
        ],
        restate: "Mornings here are always quiet.",
      ),
      _turn(
        line: "Put it on the desk by the window.",
        keyWord: 'desk',
        confusable: 'disk',
        replies: [
          _ok("On the table over there — will do."),
          _no("A disk? I don't think I was given one."),
          _no("Should I leave my name with it?"),
        ],
        restate: "Leave it on the table that's next to the window.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_d7',
    field: 'daily',
    situation: 'a message',
    title: 'A change of time',
    windowMs: 3000,
    turns: [
      _turn(
        line: "Shall we say half twelve instead?",
        keyWord: 'twelve',
        confusable: 'twenty',
        replies: [
          _ok("Half twelve suits me — I'll see you then."),
          _no("Half twenty? I'm not sure what that means."),
          _no("Could we make it a little later than that?"),
        ],
        restate: "Thirty minutes past midday, rather than when we said.",
      ),
      _turn(
        type: TurnType.polarity,
        line: "I can't stay long, though.",
        keyWord: "can't",
        confusable: 'can',
        replies: [
          _ok("A quick one, then. That's fine."),
          _no("Good, we've got all afternoon."),
          _no("Shall we make it another day instead?"),
        ],
        restate: "I'll have to be off fairly soon after we sit down.",
      ),
    ],
  ),
  _scene(
    id: 'builtin_d8',
    field: 'daily',
    situation: 'a walk',
    title: 'Which way round',
    windowMs: 2000,
    turns: [
      _turn(
        type: TurnType.multiFact,
        line: "Go left at the bridge, and it's about twenty minutes from there.",
        facts: [
          Fact(slot: 'way', value: 'left', confusable: 'right'),
          Fact(slot: 'length', value: 'twenty minutes', confusable: 'ten minutes'),
        ],
        replies: [
          _ok("Left at the bridge, twenty minutes. Got it."),
          _no("Right at the bridge, then twenty minutes.", missed: 'way'),
          _no("Left at the bridge, about ten minutes.", missed: 'length'),
        ],
        restate: "Bear left when you reach the bridge; it's a good twenty minutes after that.",
      ),
    ],
  ),
];

/// Every sample, in the order the fields are offered.
final List<Scene> baseScenes = [..._work, ..._travel, ..._school, ..._daily];
