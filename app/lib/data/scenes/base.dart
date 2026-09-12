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
    );

/// One turn. [line] asks something; [replies] is right-first, and the rest
/// are what a mishearing would answer.
Turn _turn({
  TurnType type = TurnType.keyword,
  required String line,
  String keyWord = '',
  String confusable = '',
  List<Fact> facts = const [],
  required List<Reply> replies,
}) =>
    Turn(
      type: type,
      line: line,
      keyWord: keyWord,
      confusable: confusable,
      facts: facts,
      replies: replies,
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
        line: "Can you get the file to me by Thursday morning?",
        keyWord: 'Thursday',
        confusable: 'Tuesday',
        replies: [
          _ok("Yes — I'll send it over the evening before."),
          _no("That only leaves me the weekend. Could we say midweek?"),
          _no("Is there any chance of another day? That week is full."),
        ],
      ),
      _turn(
        type: TurnType.polarity,
        line: "Can you manage without the figures until then?",
        keyWord: 'without',
        confusable: 'with',
        replies: [
          _ok("I'll work round them and fill the gaps at the end."),
          _no("Yes, having them in front of me makes it much quicker."),
          _no("Would it help if I took part of it off you?"),
        ],
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
        line: "The review call's moved back fifteen minutes — does that still suit you?",
        keyWord: 'fifteen',
        confusable: 'fifty',
        replies: [
          _ok("A quarter of an hour is fine. I'll dial in a bit later."),
          _no("That takes us right into lunch, I'm afraid."),
          _no("Has everyone been told, or shall I pass it on?"),
        ],
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
        line: "Whoever's covering starts at nine on the second floor — can you tell them?",
        facts: [
          Fact(slot: 'time', value: 'nine', confusable: 'ten'),
          Fact(slot: 'place', value: 'the second floor', confusable: 'the third floor'),
        ],
        replies: [
          _ok("Nine, second floor. I'll let them know."),
          _no("Ten on the second floor — I'll pass that on.", missed: 'time'),
          _no("Nine, up on the third floor. Got it.", missed: 'place'),
        ],
      ),
      _turn(
        line: "Could you pick up the sheet before you go up?",
        keyWord: 'sheet',
        confusable: 'seat',
        replies: [
          _ok("Will do — I'll collect the paperwork on the way."),
          _no("I can stand, honestly. It's not a long meeting."),
          _no("Is that something they hand out, or do I ask?"),
        ],
      ),
      _turn(
        type: TurnType.polarity,
        line: "Don't wait for me if the room's already open, all right?",
        keyWord: "don't",
        confusable: 'do',
        replies: [
          _ok("Sure — if it's open I'll go straight in."),
          _no("Of course. I'll hang on outside until you get there."),
          _no("Shall I text you when I arrive?"),
        ],
      ),
    ],
  ),
  _scene(
    id: 'builtin_w4',
    field: 'work',
    situation: 'a request',
    title: 'A favour before the launch',
    windowMs: 2000,
    turns: [
      _turn(
        line: "Could you look at this before the launch?",
        keyWord: 'launch',
        confusable: 'lunch',
        replies: [
          _ok("Before it goes live — yes, I'll make time today."),
          _no("That's tight, but I can manage a quick look before I eat."),
          _no("How long do you think it needs from me?"),
        ],
      ),
      _turn(
        line: "There's a copy on the desk — would you rather read it on paper?",
        keyWord: 'copy',
        confusable: 'coffee',
        replies: [
          _ok("A printout is easier, thanks. I'll pick it up."),
          _no("That's very kind, but I've just had one."),
          _no("I'll read it on screen, it's quicker for me."),
        ],
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
        line: "They're not coming in on Friday — can you take the room booking down?",
        keyWord: 'not',
        confusable: '',
        replies: [
          _ok("Of course. I'll free the room up again."),
          _no("I'll make sure it's set up for them before they arrive."),
          _no("Do we know yet who was going to come with them?"),
        ],
      ),
      _turn(
        line: "Shall we do it on the thirteenth instead?",
        keyWord: 'thirteenth',
        confusable: 'thirtieth',
        replies: [
          _ok("That's the week after next — yes, that works."),
          _no("Nearly a month away? That feels like a long wait."),
          _no("Is that fixed, or might it move again?"),
        ],
      ),
      _turn(
        type: TurnType.multiFact,
        line: "Could you book the small room for two hours from four?",
        facts: [
          Fact(slot: 'length', value: 'two hours', confusable: 'an hour'),
          Fact(slot: 'time', value: 'four', confusable: 'five'),
        ],
        replies: [
          _ok("Two hours from four. I'll put it in now."),
          _no("An hour from four — booked.", missed: 'length'),
          _no("Two hours from five, then.", missed: 'time'),
        ],
      ),
      _turn(
        line: "Would you tell the team, and copy in whoever takes the notes?",
        keyWord: 'notes',
        confusable: 'notice',
        replies: [
          _ok("I'll tell everyone and add whoever's writing it up."),
          _no("I'll send it round and give them plenty of warning."),
          _no("Shall I put it in the team channel, or send it separately?"),
        ],
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
        line: "Shall I walk over after this and look at it with you?",
        keyWord: 'walk',
        confusable: 'work',
        replies: [
          _ok("Come across whenever — I'll be at my desk."),
          _no("If you'd rather stay where you are, that's fine too."),
          _no("Great. Give me ten minutes to get it open."),
        ],
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
        line: "The last part still needs some work, doesn't it?",
        keyWord: 'work',
        confusable: 'walk',
        replies: [
          _ok("It does. I'll go back over the ending and tidy it."),
          _no("Some air would probably help — I've been staring at it."),
          _no("Is it the wording, or is something missing?"),
        ],
      ),
      _turn(
        type: TurnType.polarity,
        line: "Can you hardly read the figures in that table either?",
        keyWord: 'hardly',
        confusable: '',
        replies: [
          _ok("No, they're very hard to make out. I'll make them bigger."),
          _no("They came out clearly on mine, so it may just be the print."),
          _no("Would a chart work better than a table there?"),
        ],
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
        line: "Could you leave it with the person on the front desk?",
        keyWord: 'leave',
        confusable: 'live',
        replies: [
          _ok("I'll drop it off downstairs on my way out."),
          _no("They're nearby, aren't they? That's handy."),
          _no("Does it need signing for, or can I just hand it over?"),
        ],
      ),
      _turn(
        line: "I'll be back at half past ten — is that any use to you?",
        keyWord: 'ten',
        confusable: 'two',
        replies: [
          _ok("Yes, I'll catch you in the morning then."),
          _no("That works — I'll come by after lunch."),
          _no("Shall I leave it on your desk in the meantime?"),
        ],
      ),
      _turn(
        type: TurnType.multiFact,
        line: "Can you send it to the team channel and mark it urgent?",
        facts: [
          Fact(slot: 'channel', value: 'the team channel', confusable: 'email'),
          Fact(slot: 'mark', value: 'urgent', confusable: 'normal'),
        ],
        replies: [
          _ok("Team channel, flagged urgent. Doing it now."),
          _no("I'll email it and flag it urgent.", missed: 'channel'),
          _no("Team channel it is — I'll send it as normal.", missed: 'mark'),
        ],
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
        line: "You want platform fourteen — do you know where that is?",
        keyWord: 'fourteen',
        confusable: 'forty',
        replies: [
          _ok("Not really. Is it up the stairs or along here?"),
          _no("That many? This station must be bigger than it looks."),
          _no("I'll find it, thanks. Do I need to be there early?"),
        ],
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
        line: "The room won't be ready until two — is that all right?",
        keyWord: "won't",
        confusable: 'will',
        replies: [
          _ok("That's fine. Could I leave my bag here until then?"),
          _no("Wonderful — I'll go straight up and drop my things."),
          _no("Is there somewhere nearby you'd recommend for lunch?"),
        ],
      ),
      _turn(
        line: "Breakfast runs until half past nine — will you be down by then?",
        keyWord: 'nine',
        confusable: 'five',
        replies: [
          _ok("Yes, I'll come down before it finishes."),
          _no("That's earlier than I usually manage, I'm afraid."),
          _no("Is it in this room, or somewhere else in the building?"),
        ],
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
        line: "Take the second turning and it's on your left — have you got that?",
        facts: [
          Fact(slot: 'turning', value: 'the second', confusable: 'the third'),
          Fact(slot: 'side', value: 'left', confusable: 'right'),
        ],
        replies: [
          _ok("Second turning, left-hand side. Thank you."),
          _no("Third turning, then left. Got it.", missed: 'turning'),
          _no("Second turning and it's on the right.", missed: 'side'),
        ],
      ),
      _turn(
        line: "It's about ten minutes — are you happy to walk it?",
        keyWord: 'walk',
        confusable: 'work',
        replies: [
          _ok("Ten minutes on foot is nothing. I'll walk."),
          _no("I could get something done while I wait, I suppose."),
          _no("Is there a bus, or is that the quickest way?"),
        ],
      ),
      _turn(
        line: "Did you see the card machine by the door?",
        keyWord: 'card',
        confusable: 'cart',
        replies: [
          _ok("I did — so I can pay that way. That's a relief."),
          _no("I'll watch out for it on my way past."),
          _no("Does it take the small notes as well?"),
        ],
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
        line: "We've put you in a quiet room at the back — does that suit?",
        keyWord: 'quiet',
        confusable: 'quite',
        replies: [
          _ok("Away from the noise? Perfect, thank you."),
          _no("It sounds lovely. I'm looking forward to seeing it."),
          _no("Does it look out over the street, or the other way?"),
        ],
      ),
      _turn(
        type: TurnType.polarity,
        line: "There's no charge for changing it — shall I go ahead?",
        keyWord: 'no',
        confusable: '',
        replies: [
          _ok("Nothing to pay? Yes, please do."),
          _no("How much is it? I'll settle up now while I'm here."),
          _no("Can I change it again later if I need to?"),
        ],
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
        line: "That's thirteen altogether — how would you like to pay?",
        keyWord: 'thirteen',
        confusable: 'thirty',
        replies: [
          _ok("Cash is fine. Here you are."),
          _no("That's more than I expected. Let me check what I have."),
          _no("Can I pay part of it by card?"),
        ],
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
        line: "It's not stopping here today — did nobody tell you?",
        keyWord: 'not',
        confusable: '',
        replies: [
          _ok("No, nobody did. Which one should I take instead?"),
          _no("They did, thanks. I'll wait here on this platform."),
          _no("Is that just today, or all week?"),
        ],
      ),
      _turn(
        line: "The next one's in eighteen minutes — can you wait?",
        keyWord: 'eighteen',
        confusable: 'eighty',
        replies: [
          _ok("Under twenty minutes? Yes, I'll wait for that."),
          _no("That long? I'd better find somewhere to sit."),
          _no("Does that one stop here, at least?"),
        ],
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
        line: "It's gate twelve and boarding starts at quarter past — all clear?",
        facts: [
          Fact(slot: 'gate', value: 'twelve', confusable: 'twenty'),
          Fact(slot: 'time', value: 'quarter past', confusable: 'half past'),
        ],
        replies: [
          _ok("Gate twelve, boarding at quarter past. Thank you."),
          _no("Gate twenty, from quarter past.", missed: 'gate'),
          _no("Gate twelve, and they start at half past.", missed: 'time'),
        ],
      ),
      _turn(
        line: "Could you take the bag off the cart first?",
        keyWord: 'cart',
        confusable: 'card',
        replies: [
          _ok("Of course — I'll lift it off the trolley."),
          _no("Certainly, it's here somewhere. One moment."),
          _no("Is it too heavy, or is it the size?"),
        ],
      ),
      _turn(
        type: TurnType.polarity,
        line: "You can't take that through without a label — shall I get you one?",
        keyWord: "can't",
        confusable: 'can',
        replies: [
          _ok("Yes please. I'll write it out here."),
          _no("No need, I'll carry it through as it is."),
          _no("What usually goes on the label?"),
        ],
      ),
      _turn(
        line: "Boarding's from the desk on the left — can you see it?",
        keyWord: 'left',
        confusable: 'lift',
        replies: [
          _ok("Yes, the desk on that side. Thank you."),
          _no("I'll go and look for it. Is it well signed?"),
          _no("Should I go over now, or wait to be called?"),
        ],
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
        line: "The test is on Tuesday — will the weekend be enough for you?",
        keyWord: 'Tuesday',
        confusable: 'Thursday',
        replies: [
          _ok("It should be. I'll get most of it done on Sunday."),
          _no("With those extra days, yes, comfortably."),
          _no("How much of the term does it cover?"),
        ],
      ),
      _turn(
        type: TurnType.polarity,
        line: "You won't need the book for it — have you got everything else?",
        keyWord: "won't",
        confusable: 'will',
        replies: [
          _ok("I have, thanks. I'll leave it at home, then."),
          _no("Mine's at home, so I'll bring it in tomorrow."),
          _no("Is there anything we should bring?"),
        ],
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
        line: "Could you look at the text before next week?",
        keyWord: 'text',
        confusable: 'test',
        replies: [
          _ok("Yes, I'll read through it over the weekend."),
          _no("Is there one next week? Nobody told us."),
          _no("How long is it, roughly?"),
        ],
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
        line: "Will you take the first part and hand it in by Monday?",
        facts: [
          Fact(slot: 'part', value: 'the first part', confusable: 'the second part'),
          Fact(slot: 'day', value: 'Monday', confusable: 'Friday'),
        ],
        replies: [
          _ok("First part, in by Monday. That works."),
          _no("Second part, by Monday. Fine.", missed: 'part'),
          _no("The first part, in by Friday, then.", missed: 'day'),
        ],
      ),
      _turn(
        line: "Send it however you like — I'll accept it either way, all right?",
        keyWord: 'accept',
        confusable: 'except',
        replies: [
          _ok("That's a relief. I'll send whatever I have."),
          _no("Which part should I leave out, then?"),
          _no("Shall I send the whole thing, or just my bit?"),
        ],
      ),
      _turn(
        type: TurnType.polarity,
        line: "Could you not start the second half yet?",
        keyWord: 'not',
        confusable: '',
        replies: [
          _ok("I'll leave it and wait to hear from you."),
          _no("I'll make a start on it this evening, then."),
          _no("Is something changing in that section?"),
        ],
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
        line: "It's in room thirty this week — do you know the one?",
        keyWord: 'thirty',
        confusable: 'thirteen',
        replies: [
          _ok("Is that the big one at the end of the corridor?"),
          _no("The small one downstairs, isn't it? I know it."),
          _no("Just this week, or from now on?"),
        ],
      ),
      _turn(
        line: "Could you take a seat nearer the front?",
        keyWord: 'seat',
        confusable: 'sheet',
        replies: [
          _ok("Of course. I'll move up a few rows."),
          _no("I don't think I was given one, sorry."),
          _no("Does it matter much where we sit?"),
        ],
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
        line: "Can you confirm it before Friday?",
        keyWord: 'confirm',
        confusable: 'conform',
        replies: [
          _ok("Yes, I'll say yes to it before the end of the week."),
          _no("I'll make sure mine matches the others, then."),
          _no("Where do I do that — online, or in person?"),
        ],
      ),
      _turn(
        type: TurnType.polarity,
        line: "It's not open on Thursdays — can you come another day?",
        keyWord: 'not',
        confusable: '',
        replies: [
          _ok("I can. I'll go on Wednesday instead."),
          _no("Thursday suits me best. I'll go after class."),
          _no("What are the usual hours?"),
        ],
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
        line: "You can keep it for fourteen days — is that long enough?",
        keyWord: 'fourteen',
        confusable: 'forty',
        replies: [
          _ok("Two weeks should be plenty, thank you."),
          _no("That's far more than I'll need, but thank you."),
          _no("Can I take it out again after that?"),
        ],
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
        line: "This is much better than your first one — can you see why?",
        keyWord: 'first',
        confusable: 'worst',
        replies: [
          _ok("I think so. I've come a long way since the start."),
          _no("It would be hard to do worse than that one, I suppose."),
          _no("Not really. What made the difference?"),
        ],
      ),
      _turn(
        type: TurnType.multiFact,
        line: "Can you come on Wednesday, to the office on the ground floor?",
        facts: [
          Fact(slot: 'day', value: 'Wednesday', confusable: 'Tuesday'),
          Fact(slot: 'place', value: 'the ground floor', confusable: 'the first floor'),
        ],
        replies: [
          _ok("Wednesday, ground floor office. I'll be there."),
          _no("Tuesday, on the ground floor. Noted.", missed: 'day'),
          _no("Wednesday, first floor office, then.", missed: 'place'),
        ],
      ),
      _turn(
        type: TurnType.polarity,
        line: "Don't rewrite the whole thing — could you just fix what's marked?",
        keyWord: "don't",
        confusable: 'do',
        replies: [
          _ok("That's much easier. I'll only touch the marked parts."),
          _no("I'll start again from the beginning this week."),
          _no("Which parts should I look at first?"),
        ],
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
        line: "I've left it with the neighbour at forty — is that all right?",
        keyWord: 'forty',
        confusable: 'fourteen',
        replies: [
          _ok("That's fine, I'll knock on my way past."),
          _no("That's right down the other end, but I'll manage."),
          _no("Did they say when they'd be in?"),
        ],
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
        line: "The dessert comes with it — would you like to choose one?",
        keyWord: 'dessert',
        confusable: 'desert',
        replies: [
          _ok("Something sweet is included? Then yes, please."),
          _no("Is that the spicy one? I'd rather not, thanks."),
          _no("Could I have it without, and pay less?"),
        ],
      ),
      _turn(
        type: TurnType.polarity,
        line: "We can't do it without the card — do you have it with you?",
        keyWord: 'without',
        confusable: 'with',
        replies: [
          _ok("I do, somewhere. One second."),
          _no("I've left it at home, but that's no problem then."),
          _no("Does a photo of it count?"),
        ],
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
        line: "Can I come round at seven and bring the dog?",
        facts: [
          Fact(slot: 'time', value: 'seven', confusable: 'eleven'),
          Fact(slot: 'who', value: 'the dog', confusable: 'the children'),
        ],
        replies: [
          _ok("Seven, and the dog's welcome. See you then."),
          _no("Eleven with the dog — that's late, but fine.", missed: 'time'),
          _no("Seven, and do bring the children along.", missed: 'who'),
        ],
      ),
      _turn(
        line: "We've eaten already — is that all right?",
        keyWord: 'eaten',
        confusable: 'eating',
        replies: [
          _ok("Of course. I'll put the kettle on instead, then."),
          _no("Take your time. There's no rush at all."),
          _no("Are you sure? It's no trouble to make something."),
        ],
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
        line: "Someone can come on the fifteenth — does that work?",
        keyWord: 'fifteenth',
        confusable: 'fiftieth',
        replies: [
          _ok("The middle of the month? Yes, that's fine."),
          _no("There aren't that many days in a month, are there?"),
          _no("Is there anything earlier?"),
        ],
      ),
      _turn(
        type: TurnType.polarity,
        line: "You don't have to be in for it — shall I book it anyway?",
        keyWord: "don't",
        confusable: 'do',
        replies: [
          _ok("Please do. I'll leave the key next door and go to work."),
          _no("Then I'll take the morning off to be here."),
          _no("How would they get in?"),
        ],
      ),
      _turn(
        line: "There's a form to sign at the end — will you be around?",
        keyWord: 'form',
        confusable: 'phone',
        replies: [
          _ok("Some paperwork? I'll make sure someone's here."),
          _no("I'll keep mine on me all afternoon, then."),
          _no("Does it get left with me, or do they take it?"),
        ],
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
        line: "I'm away for a week from Sunday — could you keep an eye on things?",
        keyWord: 'Sunday',
        confusable: 'Monday',
        replies: [
          _ok("Of course. From the end of this week, then."),
          _no("So you've got the whole weekend at home first? Lovely."),
          _no("Happily. Anywhere nice, or is it work?"),
        ],
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
        line: "It's never busy here in the morning — did you not know?",
        keyWord: 'never',
        confusable: 'always',
        replies: [
          _ok("I didn't. I'll come earlier next time, then."),
          _no("I did, which is why I avoid them. Afternoons are better."),
          _no("What about later in the day?"),
        ],
      ),
      _turn(
        line: "Could you put it on the desk by the window?",
        keyWord: 'desk',
        confusable: 'disk',
        replies: [
          _ok("On the table over there? Will do."),
          _no("I don't think I was given one, sorry."),
          _no("Should I leave my name with it?"),
        ],
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
          _ok("Half twelve suits me. See you then."),
          _no("I'm not quite sure what time you mean."),
          _no("Could we make it a little later than that?"),
        ],
      ),
      _turn(
        type: TurnType.polarity,
        line: "I can't stay long, though — is that still worth it?",
        keyWord: "can't",
        confusable: 'can',
        replies: [
          _ok("A quick one is better than none. Let's do it."),
          _no("Plenty of time, then. We can take the afternoon over it."),
          _no("Shall we make it another day instead?"),
        ],
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
        line: "Go left at the bridge — it's twenty minutes from there, all right?",
        facts: [
          Fact(slot: 'way', value: 'left', confusable: 'right'),
          Fact(slot: 'length', value: 'twenty minutes', confusable: 'ten minutes'),
        ],
        replies: [
          _ok("Left at the bridge, twenty minutes. Got it."),
          _no("Right at the bridge, then twenty minutes.", missed: 'way'),
          _no("Left at the bridge, about ten minutes.", missed: 'length'),
        ],
      ),
    ],
  ),
];

/// Every sample, in the order the fields are offered.
final List<Scene> baseScenes = [..._work, ..._travel, ..._school, ..._daily];
