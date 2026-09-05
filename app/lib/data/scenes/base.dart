/// The English of every built-in scene: the line that is spoken and the three
/// replies to choose from. Shared by every interface language; the
/// translations, gists and reasons live in the per-language overlays.
///
/// The right reply is always written first. Positions are shuffled at read
/// time, deterministically, so the author never has to think about where the
/// answer sits and every language agrees on where it ended up.
library;

const List<Map<String, dynamic>> base = [
  // ---- work ------------------------------------------------------------
  {
    'id': 'builtin_w1',
    'topic': 'Turning down a request',
    'ex': [
      {
        'line':
            "Are you free on Friday afternoon? I have two meetings at the same time. Can you do the client presentation for me at three?",
        'reply': [
          "Friday at three is hard for me — my report is due then. Can we ask the client to move it to Monday?",
          "Sure, I'll sit next to you and take notes.",
          "Thanks! I'll take Friday afternoon off, then.",
        ],
      },
      {
        'line':
            "Monday is too late — the client leaves on Saturday. Could you do just the first ten minutes? I'll join by phone after that.",
        'reply': [
          "OK, ten minutes I can do. Send me the first slides, and call in at ten past three.",
          "The whole presentation? Sorry, I can't do that.",
          "Monday works. Let's start ten minutes early.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_w2',
    'topic': 'Moving a meeting',
    'ex': [
      {
        'line':
            "Can we move next week's team meeting? Thursday doesn't work for me anymore. How about Friday morning at nine?",
        'reply': [
          "Friday at nine works for me. I'll let the others know.",
          "Thursday at nine is fine with me.",
          "No meeting next week? That's fine with me.",
        ],
      },
      {
        'line':
            "Great. One more thing — can you book the small room? The big one is taken on Friday.",
        'reply': [
          "Sure, I'll book the small room for Friday at nine.",
          "OK, I'll book the big room.",
          "Great, so you'll book the room. Thanks!",
        ],
      },
    ],
  },
  {
    'id': 'builtin_w3',
    'topic': 'Owning up to a mistake',
    'ex': [
      {
        'line':
            "I got an email from the client. They say the price list has the wrong numbers. Which file did you send them?",
        'reply': [
          "I'm sorry — I think I sent the old file. I'll check right now and send the correct one.",
          "They didn't get it? I'll send it again now.",
          "Thank you! I'm glad they liked it.",
        ],
      },
      {
        'line':
            "Don't send anything yet. Fix the file, show it to me first, and then we'll send it together.",
        'reply': [
          "Understood. I'll fix it and show you before anything goes out.",
          "OK, I'm sending the new file now.",
          "Thanks for fixing it for me.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_w4',
    'topic': 'Being asked to stay late',
    'ex': [
      {
        'line':
            "Sorry to ask, but could you stay an extra hour tonight? The client moved the deadline to tomorrow morning.",
        'reply': [
          "One hour is fine. What should I start on?",
          "Sure, I'll come in early tomorrow. What time?",
          "Great, thanks! See you tomorrow then.",
        ],
      },
      {
        'line':
            "Thanks. Could you check the numbers in the report while I finish the slides? Just the totals on the last page.",
        'reply': [
          "Got it — just the totals on the last page. I'll tell you if anything looks off.",
          "OK, I'll finish the slides. Send me what you have.",
          "The whole report? That will take more than an hour.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_w5',
    'topic': 'Taking feedback',
    'ex': [
      {
        'line':
            "Your report was good, but it was too long. Nobody read the last page — and that's where your main point was.",
        'reply': [
          "I see. I'll put the main point on the first page and make it shorter.",
          "I'll add more pages with more detail.",
          "Thank you! I worked hard on the last page.",
        ],
      },
      {
        'line':
            "Good. And for the managers, make a one-page version. They only have five minutes to read it.",
        'reply': [
          "One page for the managers — got it. I'll send it to you tomorrow.",
          "Five pages for the managers? OK, I'll write more.",
          "So the managers don't need a copy. Understood.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_w6',
    'topic': 'Taking a phone message',
    'ex': [
      {
        'line':
            "Hello, is this the sales team? I'm calling about my order. Could someone call me back before five today?",
        'reply': [
          "Of course. May I have your name and number? Someone will call you back before five.",
          "Tomorrow at five is fine. We'll see you here then.",
          "I'm sorry to hear that. I'll cancel the order now.",
        ],
      },
      {
        'line':
            "Thanks. Also, please tell them the delivery address has changed. I'll send the new one by email.",
        'reply': [
          "Got it. I'll tell them the address has changed and to watch for your email.",
          "A new delivery date? Sure, what day works for you?",
          "So the address is the same. I'll send you a confirmation email.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_w7',
    'topic': 'Asking for more time',
    'ex': [
      {
        'line':
            "How is the report going? I need it by Wednesday, because the meeting is on Thursday morning.",
        'reply': [
          "Wednesday is tight. Could I send it Wednesday evening? I'm still waiting for the sales numbers.",
          "Thursday is fine. I'll send it Thursday afternoon.",
          "No report? OK, I'll stop working on it.",
        ],
      },
      {
        'line':
            "Wednesday evening is OK, but send me the first half by lunchtime. I want to read it before the rest.",
        'reply': [
          "Sure. The first half by lunch, the rest in the evening.",
          "All of it by lunch? I don't think I can make it.",
          "Great, I'll send the whole report Wednesday evening.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_w8',
    'topic': 'A business trip',
    'ex': [
      {
        'line':
            "You're going to the head office next month. Can you go on the tenth and come back on the twelfth?",
        'reply': [
          "The tenth to the twelfth — yes, that works. Should I book the train myself?",
          "The twelfth to the twentieth? That's a long trip.",
          "A day trip on the tenth is fine. I'll be back that night.",
        ],
      },
      {
        'line':
            "Book the train, but not the hotel. The office will book that for you. Just send them your arrival time.",
        'reply': [
          "OK, I'll book the train and send them my arrival time.",
          "I'll book the hotel tonight. Which one do you recommend?",
          "Great, so I don't need to book anything. Thanks!",
        ],
      },
    ],
  },
  {
    'id': 'builtin_w9',
    'topic': 'Helping a new colleague',
    'ex': [
      {
        'line':
            "We have a new colleague starting on Monday. Could you show them around and have lunch with them on the first day?",
        'reply': [
          "Sure. I'll show them around in the morning and take them to lunch.",
          "Next month? OK, remind me when they start.",
          "A presentation on Monday? I'll help them prepare.",
        ],
      },
      {
        'line':
            "Thanks. They don't have a computer yet, so please share yours until Wednesday. IT will bring a new one then.",
        'reply': [
          "No problem. They can use my computer until Wednesday.",
          "The new computer comes today? Great, then they don't need mine.",
          "I'll give my computer back to IT this afternoon.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_w10',
    'topic': 'Asking for a day off',
    'ex': [
      {
        'line':
            "You asked for the fifteenth off, right? That's fine, but the fourteenth is our busiest day, so please be here for that one.",
        'reply': [
          "Thank you. I'll be here on the fourteenth for sure.",
          "I see. Then I'll take the fourteenth off instead.",
          "Both days? Thank you, that's a nice long weekend.",
        ],
      },
      {
        'line':
            "One more thing. Before you go, please write down where your files are, so we can find them while you're away.",
        'reply': [
          "Sure, I'll leave a note with the file locations on my desk.",
          "Delete all my files? Are you sure?",
          "I'll keep my phone on, so call me anytime that day.",
        ],
      },
    ],
  },

  // ---- travel ----------------------------------------------------------
  {
    'id': 'builtin_t1',
    'topic': 'Tipping at a restaurant',
    'ex': [
      {
        'line':
            "Here's your check. Just so you know, the tip is not included. Most people leave about 18 percent.",
        'reply': [
          "OK, thanks. I'll add 18 percent.",
          "Oh, it's included? Then I'll just pay this.",
          "No tip here? Great, thanks.",
        ],
      },
      {
        'line':
            "You can add it on the card machine. It will ask you to choose a percentage.",
        'reply': [
          "Great, I'll choose 18 percent on the machine.",
          "Do you have change? I only have big bills.",
          "Here, this is for you.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_t2',
    'topic': 'Is the water free?',
    'ex': [
      {
        'line':
            "Would you like some water? Bottled water is three dollars, or tap water is free.",
        'reply': [
          "Tap water, please.",
          "Bottled water, please — since it's free.",
          "Three dollars for tap water? No, thank you.",
        ],
      },
      {
        'line':
            "Sure. And a heads-up — the kitchen is a bit slow tonight. Your food may take about thirty minutes.",
        'reply': [
          "That's OK, we're not in a hurry.",
          "You close in thirty minutes? Then we'll order now.",
          "Only three minutes? Wow, that's fast.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_t3',
    'topic': 'No booking at the hotel',
    'ex': [
      {
        'line':
            "I'm sorry, I can't find a booking under your name for tonight. Is it maybe for tomorrow?",
        'reply': [
          "It should be for tonight. Here is my confirmation email — can you check the booking number?",
          "OK, I'll wait here until the room is ready.",
          "Full tonight? Then can you recommend another hotel?",
        ],
      },
      {
        'line':
            "Ah, I found it. The booking was cancelled because your card didn't work. We still have a room, but tonight's price is twenty dollars higher.",
        'reply': [
          "My card didn't work? Nobody told me. Can I pay now at the original price?",
          "No rooms left? Then I need to find another hotel.",
          "Same price? Great, I'll pay now.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_t4',
    'topic': 'No hot water in the room',
    'ex': [
      {
        'line':
            "I'm sorry about the hot water. I can send someone to fix it in about thirty minutes, or I can move you to another room now.",
        'reply': [
          "I'll wait for the repair, thanks. Thirty minutes is fine.",
          "Tomorrow? That's too late. I need hot water tonight.",
          "Right now? Great, I'll wait by the door.",
        ],
      },
      {
        'line':
            "OK. While you wait, you can use the pool on the roof. It's open until ten.",
        'reply': [
          "Nice, I'll go to the pool then. Please call my room when it's fixed.",
          "The pool is closed? OK, I'll stay in the room.",
          "It opens at ten? That's too late for me.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_t5',
    'topic': 'The price at the register',
    'ex': [
      {
        'line':
            "That's forty-eight dollars and fifty cents. The twenty percent discount is only for members, so it's not included.",
        'reply': [
          "Members only? Can I become a member now?",
          "Oh, the discount is in? OK, here's my card.",
          "Twenty dollars? That's cheaper than I thought.",
        ],
      },
      {
        'line':
            "Yes, it's free. I just need your email address. It takes one minute.",
        'reply': [
          "OK, let's do it. My email is…",
          "It costs money? No, thanks.",
          "I don't have my ID with me. Never mind.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_t6',
    'topic': 'Asking the way',
    'ex': [
      {
        'line':
            "The museum? Take the number five bus outside the station. Not the fifteen — that one goes the other way.",
        'reply': [
          "The number five, not the fifteen. Got it, thanks!",
          "The fifteen, OK. Where does it stop?",
          "Walking is fine. Which way do I go?",
        ],
      },
      {
        'line':
            "The bus stop is across the street, next to the bank. Buy your ticket on the bus — it's two dollars, cash only.",
        'reply': [
          "Across the street by the bank, two dollars cash. Thanks a lot!",
          "Is the ticket window inside the station? I'll pay by card.",
          "It's free? Nice!",
        ],
      },
    ],
  },
  {
    'id': 'builtin_t7',
    'topic': 'The bag did not arrive',
    'ex': [
      {
        'line':
            "Your bag is still in the city you came from. It will arrive on the next flight, tonight at nine. We can deliver it to your hotel.",
        'reply': [
          "Tonight at nine — OK. Yes, please deliver it to my hotel. Here's the address.",
          "It's lost? What do I do now?",
          "Which belt is it on? I'll go get it.",
        ],
      },
      {
        'line':
            "It should arrive at your hotel by midnight. If you need anything tonight, like a toothbrush, we can give you a small kit.",
        'reply': [
          "By midnight, great. Yes, I'd like a kit, please.",
          "Tomorrow noon? How much is the kit?",
          "OK, I'll come back to the airport in the morning.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_t8',
    'topic': 'Changing trains',
    'ex': [
      {
        'line':
            "This train doesn't stop at the airport. Get off at the third stop and change to the red line.",
        'reply': [
          "Third stop, then the red line. Thanks!",
          "Great, so I can stay on this train.",
          "Next stop, the blue line. OK.",
        ],
      },
      {
        'line':
            "Your ticket is fine for the red line too, so don't buy a new one. The airport is the last stop.",
        'reply': [
          "Same ticket, last stop. Perfect, thank you.",
          "Where can I buy a ticket for the red line?",
          "The second stop? I'll watch for it.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_t9',
    'topic': 'Ordering at a cafe',
    'ex': [
      {
        'line':
            "The chicken sandwich is sold out, sorry. We still have the egg sandwich and the soup. The soup comes with bread.",
        'reply': [
          "The soup with bread, please.",
          "The chicken sandwich, please.",
          "Everything's sold out? Just a coffee, then.",
        ],
      },
      {
        'line':
            "For here or to go? If you eat here, it takes about ten minutes. To go is faster.",
        'reply': [
          "To go, please. I'm in a bit of a hurry.",
          "For here — it's faster, right?",
          "Only to go today? OK.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_t10',
    'topic': 'At the pharmacy',
    'ex': [
      {
        'line':
            "For a headache, this one is good. Take one tablet with water, and not more than three a day.",
        'reply': [
          "One tablet, up to three a day. Thanks. How much is it?",
          "Three tablets at once, once a day. Got it.",
          "As many as I want? Great.",
        ],
      },
      {
        'line':
            "Don't take it on an empty stomach. And if the headache is still there after two days, please see a doctor.",
        'reply': [
          "Not on an empty stomach, and a doctor if it lasts two days. OK.",
          "Before eating, right? I'll take one now.",
          "I should see a doctor now? Where is the hospital?",
        ],
      },
    ],
  },

  // ---- school ----------------------------------------------------------
  {
    'id': 'builtin_s1',
    'topic': 'When the essay is due',
    'ex': [
      {
        'line':
            "Your essays are due next Monday, not this Friday. And please email them to me — don't print them.",
        'reply': [
          "Next Monday by email. Got it, thank you.",
          "Friday? OK, I'll print it and bring it.",
          "Monday, OK. Should I leave the printed copy on your desk?",
        ],
      },
      {
        'line':
            "It should be about five hundred words. Anything over eight hundred is too long, and I'll stop reading.",
        'reply': [
          "About five hundred words, and under eight hundred. OK.",
          "Eight hundred words? That's a lot. I'll try.",
          "No word limit? Great, I have a lot to say.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_s2',
    'topic': 'A group presentation',
    'ex': [
      {
        'line':
            "Can you make the slides? I'll write the script. Let's meet on Thursday after class to practice.",
        'reply': [
          "Sure, I'll do the slides. See you Thursday after class.",
          "OK, I'll write the script. Send me your slides by Thursday.",
          "Both? That's a lot for one person, but OK.",
        ],
      },
      {
        'line':
            "Our talk is only five minutes, so no more than six slides. And use big letters — the room is huge.",
        'reply': [
          "Six slides max, big letters. Got it.",
          "At least five slides, OK. I'll make about ten.",
          "Fifteen minutes? Then we need a lot of slides.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_s3',
    'topic': 'Borrowing books',
    'ex': [
      {
        'line':
            "You can borrow these two for three weeks. This one is a reference book, so it can't leave the library.",
        'reply': [
          "OK, I'll take these two and read that one here.",
          "All three for two weeks? Great.",
          "None of them? OK, I'll read them here.",
        ],
      },
      {
        'line':
            "If you need them longer, you can renew online once. After that, please bring them back.",
        'reply': [
          "Renew once online — good to know. Thanks.",
          "No renewals? OK, I'll read fast.",
          "I can renew as many times as I want? Great.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_s4',
    'topic': 'Missing a class',
    'ex': [
      {
        'line':
            "If you miss tomorrow's class, that's fine. Just watch the video I post and do the short quiz by Sunday.",
        'reply': [
          "Thank you. I'll watch the video and do the quiz by Sunday.",
          "A test tomorrow? Then I'll come even if I'm sick.",
          "Nothing to do? Great, I'll rest.",
        ],
      },
      {
        'line':
            "One thing — the quiz closes at midnight on Sunday, and you can only take it once, so don't rush.",
        'reply': [
          "Once only, before midnight Sunday. I'll take my time.",
          "I can try it a few times? Good, I'll practice first.",
          "Monday morning, OK. I'll do it Sunday night.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_s5',
    'topic': 'A change of practice',
    'ex': [
      {
        'line':
            "Practice is cancelled on Wednesday because of the rain. We'll practice on Saturday morning instead, at eight.",
        'reply': [
          "Saturday at eight, got it. Thanks for letting me know.",
          "Wednesday at eight? OK, I'll be there.",
          "Both cancelled? Nice, a free week.",
        ],
      },
      {
        'line':
            "Bring your own water — the machine is broken. And wear the blue shirt, not the white one. We're taking a team photo.",
        'reply': [
          "Water and the blue shirt. See you Saturday!",
          "I'll buy water there and wear the white shirt.",
          "No photo? Then any shirt is fine, right?",
        ],
      },
    ],
  },

  // ---- everyday --------------------------------------------------------
  {
    'id': 'builtin_d1',
    'topic': 'A missed delivery',
    'ex': [
      {
        'line':
            "I have a package for you, but nobody's home. I can come back tomorrow morning, or you can pick it up at the office.",
        'reply': [
          "Tomorrow morning is fine. Around nine, please.",
          "Tonight? Sure, I'll be home by eight.",
          "You sent it back? But I need it!",
        ],
      },
      {
        'line':
            "Tomorrow between nine and eleven, then. Please leave a note on the door if you go out.",
        'reply': [
          "Nine to eleven, OK. I'll be home.",
          "Eleven sharp? I'll wait with my ID.",
          "Nine at night? That's late, but OK.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_d2',
    'topic': "A neighbour's favour",
    'ex': [
      {
        'line':
            "I'm going away for the weekend. Could you water my plants on Saturday? Just the ones on the balcony.",
        'reply': [
          "Sure. Just the balcony ones on Saturday. Have a good trip!",
          "Sure, I'll feed the cat. Where is the food?",
          "Bring them over. I'll keep them at my place.",
        ],
      },
      {
        'line':
            "Thanks! The key is under the mat. I'll be back Sunday night, so I'll pick it up on Monday.",
        'reply': [
          "Under the mat, got it. See you Monday.",
          "Saturday night? OK, I'll give the key back then.",
          "The door will be open? Isn't that dangerous?",
        ],
      },
    ],
  },
  {
    'id': 'builtin_d3',
    'topic': "Booking a doctor's visit",
    'ex': [
      {
        'line':
            "The doctor is full today. The next open time is Thursday at two, or Friday at ten in the morning.",
        'reply': [
          "Friday at ten, please.",
          "Today at two? Great, I'll come.",
          "Closed Thursday and Friday? What about Monday?",
        ],
      },
      {
        'line':
            "Please come ten minutes early, and bring your insurance card. If you can't come, call us the day before.",
        'reply': [
          "Ten minutes early, with my insurance card. Thank you.",
          "It's fine to be ten minutes late? OK.",
          "I'll call you Friday morning to confirm.",
        ],
      },
    ],
  },
  {
    'id': 'builtin_d4',
    'topic': 'Fixing a phone screen',
    'ex': [
      {
        'line':
            "We can fix the screen today. It takes about two hours and costs ninety dollars. Or a new phone is two hundred.",
        'reply': [
          "I'll fix it, please. I'll come back in two hours.",
          "Two days and two hundred? That's a lot. Let me think.",
          "It can't be fixed? OK, I'll buy a new one.",
        ],
      },
      {
        'line':
            "Please back up your photos first. Sometimes we have to reset the phone, and then everything is gone.",
        'reply': [
          "OK, I'll back up my photos now before you start.",
          "My photos are safe? Good, go ahead.",
          "You'll back them up for me? Thanks!",
        ],
      },
    ],
  },
  {
    'id': 'builtin_d5',
    'topic': 'Joining a gym',
    'ex': [
      {
        'line':
            "It's thirty dollars a month, and the first month is free. You can cancel any time — just tell us one week before.",
        'reply': [
          "Thirty a month, first month free. OK, I'd like to join.",
          "A one-year contract? Hmm, I'm not sure.",
          "Everything is free? Wow, sign me up!",
        ],
      },
      {
        'line':
            "The gym opens at six in the morning and closes at ten at night. On Sundays, it closes at six.",
        'reply': [
          "Six to ten, and till six on Sundays. Got it.",
          "Closed on Sundays? That's a shame.",
          "Open all night? Great, I'll come late.",
        ],
      },
    ],
  },
];
