/// English interface: the setting, the three gists and the reasons. The line
/// and the replies need no translation, so there is none — the screen hides
/// an empty translation.
library;

const Map<String, Map<String, dynamic>> en = {
  // ---- work ------------------------------------------------------------
  'builtin_w1': {
    'setting': 'A colleague asks you to give their Friday presentation',
    'ex': [
      {
        'gist': [
          'They want you to give the presentation at three on Friday',
          'They want you to sit in on a meeting at three on Friday',
          'They are saying you can take Friday afternoon off',
        ],
        'why': [
          'Takes the request as a request and offers a way out',
          'Heard "do it for me" as "come along with me"',
          'Heard a request as permission to take the afternoon off',
        ],
      },
      {
        'gist': [
          'Do only the first ten minutes; they join by phone after that',
          'Do the whole thing; they cannot be there at all',
          'The talk moved to Monday and starts ten minutes early',
        ],
        'why': [
          'Takes "ten minutes, then by phone" as said',
          'Heard "the first ten minutes" as "the whole presentation"',
          'Missed "Monday is too late"',
        ],
      },
    ],
  },
  'builtin_w2': {
    'setting': 'Your manager asks about moving next week\'s meeting',
    'ex': [
      {
        'gist': [
          'Move the Thursday meeting to Friday at nine',
          'Move the Friday meeting to Thursday at nine',
          'Cancel next week\'s meeting',
        ],
        'why': [
          'Takes "to Friday at nine" as said',
          'Swapped Thursday and Friday',
          'Heard "move" as "cancel"',
        ],
      },
      {
        'gist': [
          'Book the small room; the big one is taken on Friday',
          'Book the big room; the small one is taken',
          'They will book the room themselves; nothing to do',
        ],
        'why': [
          'Takes "you book the small room" as said',
          'Swapped big and small',
          'Heard a request as something the other person will do',
        ],
      },
    ],
  },
  'builtin_w3': {
    'setting': 'Your manager, about a price list you sent a client',
    'ex': [
      {
        'gist': [
          'The client says the numbers are wrong; which file did you send?',
          'The client says the price list never arrived',
          'The client liked the price list',
        ],
        'why': [
          'Answers the mistake and the question about the file',
          'Heard "wrong numbers" as "did not arrive"',
          'Heard a complaint as praise',
        ],
      },
      {
        'gist': [
          'Send nothing yet; fix it, show them first, then send together',
          'Resend right away; report to them later',
          'They will fix and send it themselves',
        ],
        'why': [
          'Takes "not yet, show me first" as said',
          'Missed "don\'t send anything yet"',
          'Heard "you fix it" as "I will fix it"',
        ],
      },
    ],
  },
  'builtin_w4': {
    'setting': 'Just before closing time, a colleague',
    'ex': [
      {
        'gist': [
          'Stay one extra hour tonight; the deadline moved to tomorrow morning',
          'Come in an hour early tomorrow; the deadline is tomorrow evening',
          'Go home early tonight; the deadline moved to next week',
        ],
        'why': [
          'Takes "one hour tonight" and gets going',
          'Heard "stay tonight" as "come early tomorrow"',
          'Heard "stay" as "you can go"',
        ],
      },
      {
        'gist': [
          'Check the totals on the last page of the report',
          'Finish the slides; they will do the report',
          'Read the whole report from start to finish',
        ],
        'why': [
          'Takes "just the totals" as said',
          'Swapped the two jobs',
          'Heard "just the totals" as "the whole report"',
        ],
      },
    ],
  },
  'builtin_w5': {
    'setting': 'Your manager, about a report you handed in',
    'ex': [
      {
        'gist': [
          'It was too long; the main point was on the last page and nobody read it',
          'It was too short; the main point was missing',
          'It was good, especially the last page',
        ],
        'why': [
          'Takes "too long, main point last" as said',
          'Heard "too long" as "too short"',
          'Heard "nobody read it" as "it was good"',
        ],
      },
      {
        'gist': [
          'Make a one-page version for the managers; they have five minutes',
          'Make a five-page version for the managers; they have plenty of time',
          'The managers need nothing',
        ],
        'why': [
          'Takes "one page" as said',
          'Heard "one page, five minutes" as "five pages"',
          'Missed "make a version"',
        ],
      },
    ],
  },
  'builtin_w6': {
    'setting': 'A call comes in for a colleague who is out',
    'ex': [
      {
        'gist': [
          'About an order; call them back before five today',
          'About an order; they will come in tomorrow at five',
          'They want to cancel the order',
        ],
        'why': [
          'Takes "call back before five" as said',
          'Heard "call me back" as "I will come in tomorrow"',
          'Heard "about my order" as "cancel my order"',
        ],
      },
      {
        'gist': [
          'The delivery address changed; the new one comes by email',
          'The delivery date changed; the new one comes by phone',
          'The address is the same; they want a confirmation email',
        ],
        'why': [
          'Takes "address changed, by email" as said',
          'Heard "address" as "date"',
          'Heard "has changed" as "is the same"',
        ],
      },
    ],
  },
  'builtin_w7': {
    'setting': 'Your manager asks how the report is coming along',
    'ex': [
      {
        'gist': [
          'The report is due Wednesday; the meeting is Thursday morning',
          'The report is due Thursday; the meeting is Friday',
          'The report is no longer needed; the meeting is off',
        ],
        'why': [
          'Takes "by Wednesday" and asks for the latest possible time',
          'Heard "Wednesday" as "Thursday" — the meeting is Thursday morning',
          'Heard "I need it" as "I don\'t need it"',
        ],
      },
      {
        'gist': [
          'Wednesday evening is fine, but the first half by lunchtime',
          'All of it by lunchtime; evening is too late',
          'Wednesday evening is fine, all of it',
        ],
        'why': [
          'Takes "first half at lunch, rest in the evening" as said',
          'Heard "the first half" as "all of it"',
          'Missed "the first half by lunchtime"',
        ],
      },
    ],
  },
  'builtin_w8': {
    'setting': 'Your manager, about next month\'s trip',
    'ex': [
      {
        'gist': [
          'Next month: go on the tenth, back on the twelfth',
          'Next month: go on the twelfth, back on the twentieth',
          'This month: a day trip on the tenth',
        ],
        'why': [
          'Takes "tenth to twelfth" as said',
          'Misheard the dates',
          'Heard "back on the twelfth" as a day trip',
        ],
      },
      {
        'gist': [
          'Book the train yourself; the office books the hotel, so send your arrival time',
          'Book the hotel yourself; the office books the train',
          'The office books everything; nothing to do',
        ],
        'why': [
          'Takes "train yours, hotel theirs" as said',
          'Swapped train and hotel',
          'Missed "book the train"',
        ],
      },
    ],
  },
  'builtin_w9': {
    'setting': 'Your manager, about a colleague starting next week',
    'ex': [
      {
        'gist': [
          'Someone starts Monday; show them around and have lunch with them',
          'Someone starts next month; nothing to do for now',
          'The new person gives a presentation at Monday\'s meeting',
        ],
        'why': [
          'Takes "show them around, lunch" as said',
          'Heard "Monday" as "next month"',
          'Heard "show around and lunch" as "presentation"',
        ],
      },
      {
        'gist': [
          'Share your computer until Wednesday; IT brings a new one then',
          'The new computer arrives today; nothing to do',
          'Give your computer back to IT; a new one comes Wednesday',
        ],
        'why': [
          'Takes "share until Wednesday" as said',
          'Heard "Wednesday" as "today"',
          'Heard "share" as "give back"',
        ],
      },
    ],
  },
  'builtin_w10': {
    'setting': 'Talking with your manager about next month\'s day off',
    'ex': [
      {
        'gist': [
          'The fifteenth off is fine; the fourteenth is busy, so be there',
          'Not the fifteenth; the fourteenth would be fine',
          'Both days off are fine',
        ],
        'why': [
          'Takes "fifteenth yes, fourteenth here" as said',
          'Swapped the fourteenth and fifteenth',
          'Missed "be here for the fourteenth"',
        ],
      },
      {
        'gist': [
          'Before you go, write down where your files are',
          'Before you go, delete all your files',
          'Answer your phone on your day off',
        ],
        'why': [
          'Takes "write down where they are" as said',
          'Heard "write down" as "delete"',
          'Nobody asked about the phone',
        ],
      },
    ],
  },

  // ---- travel ----------------------------------------------------------
  'builtin_t1': {
    'setting': 'The check arrives after dinner at a restaurant',
    'ex': [
      {
        'gist': [
          'The tip is not included; about 18 percent is usual',
          'The tip is included; nothing to add',
          'No tipping at this restaurant',
        ],
        'why': [
          'Takes "not included, 18 percent" as said',
          'Heard "not included" as "included"',
          'Heard "leave a tip" as "no tip"',
        ],
      },
      {
        'gist': [
          'Add it on the card machine by choosing a percentage',
          'Leave cash on the table',
          'Hand it to the server',
        ],
        'why': [
          'Takes "choose on the machine" as said',
          'Heard it as paying in cash',
          'Heard it as handing it over',
        ],
      },
    ],
  },
  'builtin_t2': {
    'setting': 'Just seated at a restaurant',
    'ex': [
      {
        'gist': [
          'Bottled water is three dollars; tap water is free',
          'All water is free',
          'All water is three dollars',
        ],
        'why': [
          'Takes "tap water is free" and chooses',
          'The free one is tap water — misheard',
          'The three dollars is for bottled — swapped',
        ],
      },
      {
        'gist': [
          'The food may take about thirty minutes tonight',
          'They close in thirty minutes, so hurry',
          'The food comes in three minutes',
        ],
        'why': [
          'Takes "it will take a while" as said',
          'Heard "slow kitchen" as "closing"',
          'Heard thirty as three',
        ],
      },
    ],
  },
  'builtin_t3': {
    'setting': 'Checking in at the hotel desk',
    'ex': [
      {
        'gist': [
          'No booking for tonight; could it be for tomorrow?',
          'There is a booking for tonight; wait for the room',
          'There is a booking for tomorrow, but tonight is full',
        ],
        'why': [
          'Answers "not found, tomorrow?" with proof',
          'Heard "no booking" as "room being prepared"',
          'Nobody said "full"',
        ],
      },
      {
        'gist': [
          'Cancelled because the card failed; a room is left, twenty dollars more',
          'Cancelled because the card failed; no rooms left',
          'The booking is fine; same price',
        ],
        'why': [
          'Takes "cancelled, room left, higher price" and asks',
          'Heard "we still have a room" as "no rooms"',
          'Missed "twenty dollars higher"',
        ],
      },
    ],
  },
  'builtin_t4': {
    'setting': 'No hot water in the shower; you called the front desk',
    'ex': [
      {
        'gist': [
          'Repair in thirty minutes, or move to another room now',
          'Repair tomorrow; no room change possible',
          'Repair right now; no need to move',
        ],
        'why': [
          'Takes "repair in thirty or move now" and chooses',
          'Heard "thirty minutes" as "tomorrow"',
          '"Now" was the room change, not the repair',
        ],
      },
      {
        'gist': [
          'While waiting, use the roof pool; open until ten',
          'The pool is closed today',
          'The pool opens at ten',
        ],
        'why': [
          'Takes "open until ten" as said',
          'Heard "open" as "closed"',
          'Heard "until ten" as "from ten"',
        ],
      },
    ],
  },
  'builtin_t5': {
    'setting': 'At the register with an item the shelf said was 20% off',
    'ex': [
      {
        'gist': [
          'Total 48.50; the 20% discount is members only, so not included',
          'Total 48.50; the 20% discount is already in',
          'Total twenty dollars; no discount',
        ],
        'why': [
          'Takes "members only, not included" and acts on it',
          'Heard "not included" as "included"',
          'Heard "twenty percent" as "twenty dollars"',
        ],
      },
      {
        'gist': [
          'Membership is free; just an email address, one minute',
          'Membership costs money and takes time',
          'Membership needs ID and can\'t be done today',
        ],
        'why': [
          'Takes "free, email, one minute" and goes ahead',
          'Heard "free" as "costs money"',
          'What is needed is an email address — misheard',
        ],
      },
    ],
  },
  'builtin_t6': {
    'setting': 'At the station, asking the way to the museum',
    'ex': [
      {
        'gist': [
          'Take the number five bus; the fifteen goes the other way',
          'Take the number fifteen bus; the five goes the other way',
          'No bus; walk',
        ],
        'why': [
          'Takes "five, not fifteen" as said',
          'Heard five as fifteen',
          'Heard "take the bus" as "walk"',
        ],
      },
      {
        'gist': [
          'The stop is across the street by the bank; two dollars cash on the bus',
          'The stop is inside the station; pay by card at the window',
          'The bus is free',
        ],
        'why': [
          'Takes "across the street, by the bank, cash" as said',
          'Heard "cash on the bus" as "card at a window"',
          'Missed "two dollars"',
        ],
      },
    ],
  },
  'builtin_t7': {
    'setting': 'Your bag did not come out; at the airport counter',
    'ex': [
      {
        'gist': [
          'The bag is still where you left from; arrives tonight at nine; can be delivered to the hotel',
          'The bag is lost; it cannot be found',
          'The bag is on another belt; go and get it',
        ],
        'why': [
          'Takes "tonight at nine, hotel delivery" as said',
          'Heard "arrives tonight" as "lost"',
          'Heard "still in the other city" as "on another belt"',
        ],
      },
      {
        'gist': [
          'At the hotel by midnight; a small kit tonight if you need one',
          'At the hotel tomorrow noon; the kit costs money',
          'Come back to the airport tomorrow morning',
        ],
        'why': [
          'Takes "by midnight, a kit" as said',
          'Misheard "by midnight" and "we can give you"',
          'Heard "to your hotel" as "come back to the airport"',
        ],
      },
    ],
  },
  'builtin_t8': {
    'setting': 'On the platform, asking a station worker',
    'ex': [
      {
        'gist': [
          'This train skips the airport; get off at the third stop, change to the red line',
          'This train goes to the airport; no change',
          'Get off at the next stop, change to the blue line',
        ],
        'why': [
          'Takes "third stop, red line" as said',
          'Heard "doesn\'t stop" as "goes there"',
          'Misheard "third" and "red"',
        ],
      },
      {
        'gist': [
          'The same ticket works; the airport is the last stop',
          'Buy a new ticket for the red line; the airport is the second stop',
          'The ticket does not work at the airport',
        ],
        'why': [
          'Takes "don\'t buy, last stop" as said',
          'Missed "don\'t buy a new one"',
          'Heard "last stop" as "second stop"',
        ],
      },
    ],
  },
  'builtin_t9': {
    'setting': 'Ordering at a cafe',
    'ex': [
      {
        'gist': [
          'Chicken is sold out; egg sandwich and soup remain; soup comes with bread',
          'Chicken is available; egg is sold out',
          'Everything is sold out; drinks only',
        ],
        'why': [
          'Chooses from what is left',
          'Missed "sold out"',
          'Heard "the chicken is sold out" as "everything"',
        ],
      },
      {
        'gist': [
          'Eating here takes ten minutes; to go is faster',
          'To go takes ten minutes; eating here is faster',
          'To go only today',
        ],
        'why': [
          'Takes "to go is faster" and chooses',
          'The faster one is to go — swapped',
          'Eating here was offered',
        ],
      },
    ],
  },
  'builtin_t10': {
    'setting': 'At the pharmacy with a headache',
    'ex': [
      {
        'gist': [
          'One tablet at a time; no more than three a day',
          'Three tablets at a time; once a day',
          'One tablet at a time; as many as you like',
        ],
        'why': [
          'Takes "one, up to three" as said',
          'Swapped one and three',
          'Missed "not more than three"',
        ],
      },
      {
        'gist': [
          'Not on an empty stomach; see a doctor if it lasts two days',
          'On an empty stomach; it clears up in two days',
          'See a doctor right now',
        ],
        'why': [
          'Takes "not empty, doctor after two days" as said',
          'Heard "don\'t take it on an empty stomach" backwards',
          'Missed "after two days"',
        ],
      },
    ],
  },

  // ---- school ----------------------------------------------------------
  'builtin_s1': {
    'setting': 'The teacher, at the end of class',
    'ex': [
      {
        'gist': [
          'Due next Monday; send by email',
          'Due this Friday; hand in on paper',
          'Due next Monday; hand in on paper',
        ],
        'why': [
          'Takes "Monday, email" as said',
          'Missed "not Friday" and "don\'t print"',
          'Missed "don\'t print them"',
        ],
      },
      {
        'gist': [
          'About five hundred words; over eight hundred is too long',
          'About eight hundred words; five hundred is too short',
          'Any length',
        ],
        'why': [
          'Takes "five hundred, under eight hundred" as said',
          'Swapped five hundred and eight hundred',
          'Missed "over eight hundred is too long"',
        ],
      },
    ],
  },
  'builtin_s2': {
    'setting': 'Preparing a presentation with a classmate',
    'ex': [
      {
        'gist': [
          'You make the slides, they write the script; practice Thursday after class',
          'You write the script, they make the slides; practice Thursday at lunch',
          'You do everything; they cannot come',
        ],
        'why': [
          'Takes "slides, Thursday after class" as said',
          'Swapped the two jobs',
          'Missed "I\'ll write the script"',
        ],
      },
      {
        'gist': [
          'Five minutes; six slides at most; big letters',
          'Six minutes; at least five slides',
          'Fifteen minutes; any number of slides',
        ],
        'why': [
          'Takes "six max, big letters" as said',
          'Heard "no more than six" as "at least five"',
          'Heard five as fifteen',
        ],
      },
    ],
  },
  'builtin_s3': {
    'setting': 'At the library counter, borrowing books',
    'ex': [
      {
        'gist': [
          'Two books for three weeks; one cannot leave the library',
          'All three for two weeks',
          'None can be borrowed; read them here',
        ],
        'why': [
          'Takes "two yes, one stays" as said',
          'Missed "can\'t leave the library"',
          'Missed "you can borrow these two"',
        ],
      },
      {
        'gist': [
          'Renew online once; then bring them back',
          'No renewals; return in three weeks',
          'Renew as often as you like',
        ],
        'why': [
          'Takes "once, online" as said',
          'Heard "once" as "not at all"',
          'Missed "once"',
        ],
      },
    ],
  },
  'builtin_s4': {
    'setting': 'Feeling ill, talking to the teacher',
    'ex': [
      {
        'gist': [
          'Missing is fine; watch the video and do the quiz by Sunday',
          'You cannot miss; there is a test tomorrow',
          'Missing is fine; nothing to do',
        ],
        'why': [
          'Takes "video, quiz, Sunday" as said',
          'Misheard "that\'s fine" and "quiz by Sunday"',
          'Missed "video and quiz"',
        ],
      },
      {
        'gist': [
          'Closes midnight Sunday; one attempt only',
          'Closes noon Sunday; unlimited attempts',
          'Closes Monday morning; two attempts',
        ],
        'why': [
          'Takes "midnight, once" as said',
          'Missed "only once"',
          'Heard "midnight Sunday" as "Monday morning"',
        ],
      },
    ],
  },
  'builtin_s5': {
    'setting': 'A message from the club captain about practice',
    'ex': [
      {
        'gist': [
          'Wednesday is cancelled; practice Saturday morning at eight instead',
          'Practice Wednesday at eight; Saturday is off',
          'Both Wednesday and Saturday are cancelled',
        ],
        'why': [
          'Takes "Wednesday off, Saturday at eight" as said',
          'Missed "Wednesday is cancelled"',
          'Missed "Saturday instead"',
        ],
      },
      {
        'gist': [
          'Bring water; wear the blue shirt; there is a team photo',
          'Water is for sale there; wear the white shirt',
          'Any shirt is fine; no photo',
        ],
        'why': [
          'Takes "own water, blue" as said',
          'Misheard "machine is broken" and "blue"',
          'Missed "team photo"',
        ],
      },
    ],
  },

  // ---- everyday --------------------------------------------------------
  'builtin_d1': {
    'setting': 'The delivery driver calls',
    'ex': [
      {
        'gist': [
          'Redelivery tomorrow morning, or pick it up at the office',
          'They will come again tonight',
          'The package went back to the sender',
        ],
        'why': [
          'Takes "tomorrow morning or the office" and chooses',
          'Heard "tomorrow morning" as "tonight"',
          'Nobody said "sent back"',
        ],
      },
      {
        'gist': [
          'Tomorrow nine to eleven; leave a note if you go out',
          'Tomorrow at eleven sharp; a signature is needed',
          'Tomorrow at nine at night; they will phone',
        ],
        'why': [
          'Takes "nine to eleven" as said',
          'Heard "between nine and eleven" as "eleven sharp"',
          'Heard morning as night',
        ],
      },
    ],
  },
  'builtin_d2': {
    'setting': 'A neighbour at your door',
    'ex': [
      {
        'gist': [
          'Water the balcony plants on Saturday',
          'Feed the cat on Saturday',
          'Keep the plants at your place over the weekend',
        ],
        'why': [
          'Takes "Saturday, balcony" as said',
          'Heard "plants" as "cat"',
          'Heard "water them" as "keep them"',
        ],
      },
      {
        'gist': [
          'The key is under the mat; back Sunday night; collects it Monday',
          'They hand over the key now; back Saturday night',
          'No key needed; the door is open',
        ],
        'why': [
          'Takes "mat, Monday" as said',
          'Heard "Sunday night" as "Saturday"',
          'Misheard "the key is under the mat"',
        ],
      },
    ],
  },
  'builtin_d3': {
    'setting': 'Calling the clinic for an appointment',
    'ex': [
      {
        'gist': [
          'Full today; Thursday at two or Friday at ten are open',
          'You can come today at two',
          'Closed Thursday and Friday',
        ],
        'why': [
          'Chooses from "Thursday at two or Friday at ten"',
          'Missed "full today"',
          'Heard "open" as "closed"',
        ],
      },
      {
        'gist': [
          'Come ten minutes early with your insurance card; call the day before if you can\'t come',
          'Ten minutes late is fine; no insurance card needed',
          'Call the morning of to confirm',
        ],
        'why': [
          'Takes "ten early, insurance card" as said',
          'Heard "early" as "late"',
          'Misheard "call the day before if you can\'t come"',
        ],
      },
    ],
  },
  'builtin_d4': {
    'setting': 'At the phone shop with a cracked screen',
    'ex': [
      {
        'gist': [
          'Repair today: two hours, ninety dollars; a new phone is two hundred',
          'Repair takes two days and costs two hundred',
          'It can\'t be fixed; buy a new one',
        ],
        'why': [
          'Takes "two hours, ninety" and chooses',
          'Misheard "two hours" and "ninety"',
          'Heard "we can fix it" as "we can\'t"',
        ],
      },
      {
        'gist': [
          'Back up your photos first; a reset may wipe everything',
          'The photos are safe; nothing to do',
          'The shop will back them up for you',
        ],
        'why': [
          'Takes "back up first" as said',
          'Missed "everything is gone"',
          'Heard "you back up" as "we back up"',
        ],
      },
    ],
  },
  'builtin_d5': {
    'setting': 'Asking about prices at the gym front desk',
    'ex': [
      {
        'gist': [
          'Thirty a month; first month free; cancel any time with a week\'s notice',
          'Thirty a month; a one-year contract, no cancelling',
          'Everything is free',
        ],
        'why': [
          'Takes "thirty, first month free" as said',
          'Missed "cancel any time"',
          'Missed "the first month"',
        ],
      },
      {
        'gist': [
          'Open six in the morning to ten at night; closes at six on Sundays',
          'Open ten to six; closed Sundays',
          'Open twenty-four hours',
        ],
        'why': [
          'Takes "six to ten, six on Sundays" as said',
          'Heard "closes at six" as "closed"',
          'Missed "closes at ten"',
        ],
      },
    ],
  },
};
