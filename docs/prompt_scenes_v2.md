# “会話”生成プロンプト（新形式・試作版）

フェーズ2aの成果物。このファイルの `--- PROMPT ---` から下をそのまま
ChatGPT / Claude / Gemini に貼って、出力の質を確かめる。

確かめること。

1. **3つの返答が、読むだけでは絞れないか。** 台詞を隠して返答3つだけを見せたとき、
   どれが正解か分からないこと。分かるなら形式が成立していない。
2. **3つとも会話として自然か。** 明らかにおかしい返答が混じっていないこと。
3. **型の指示が守られているか。** `polarity` の誤答が「反転語を聞き逃した人が選ぶもの」に
   なっているか。`multiFact` の誤答が `missedSlot` と一対一に対応しているか。
4. **同じ形の使い回しになっていないか。** `keyword` と `polarity` で、
   返答が「一語だけ違う双子」になっていないこと。

---

## 設計上の注意（プロンプトに入れてある理由）

### 双子の返答を禁じている理由

ブリーフの例は、返答が一語だけ違う形になっている。

```
"Sure, four works for me."
"Sure, three works for me."
```

これだと学習者は「答えはこの2つのどちらか」と即座に絞れてしまい、
実質2択になる。読むだけで絞れてはいけないという要件に反する。
`keyword` と `polarity` では、**返答の言い回しそのものを変える**よう指示している。

`multiFact` だけは例外。誤答が「どの情報を取り落としたか」と一対一に対応する必要があるので、
返答は並行した形になる。この場合でも、3つとも「待ち合わせの確認」として自然なので、
読むだけでは絞れない。

### 目隠しテストをプロンプトに入れている理由

「読むだけでは絞れない」は抽象的で、AI が自己判定しにくい。
**台詞を隠して返答3つだけを見て、正解が分かってしまわないか**という
具体的な手続きに落とすと、自己点検できる。

---

--- PROMPT ---

You are writing listening practice for one person learning English.

They hear a line of speech **once**, then choose one of three replies. They
never see the line written down. A machine can translate for them; what it
cannot do is keep up with a conversation in real time. That is what this
practice is for.

## THE PERSON

- English level: {LEVEL}
- Age group: {AGE}
- What they do: {ROLES}
- Where they want English: {PRIORITIES}
- Their language: {NATIVE_LANGUAGE}
- This set is about: {SITUATION}

## WHAT TO WRITE

{COUNT} conversations. Output JSON only, no commentary.

A conversation is 1 to 5 turns. **Vary the length across the set.** A quick
exchange in a corridor is one turn; a phone call about a change of plan is
four or five. Do not make them all the same length.

Each turn is: the other person says one line, and the learner picks one of
three replies.

## THE ONE RULE THAT MATTERS

**The three replies must all be natural, and only the sound of the line may
decide which is right.**

Test it like this, for every turn you write, before you output it:

> Hide the line. Show only the situation and the three replies to a native
> speaker. If they can tell which one is correct, the turn is broken.

A reply is broken if it is rude, off-topic, ungrammatical, or obviously
strange. Someone who misheard the line must be able to choose it without
feeling that they are choosing something odd.

## THE THREE TYPES

Mix them across the set: about half `keyword`, a quarter `polarity`, a
quarter `multiFact`. Do not make a whole conversation one type; mix within a
conversation too.

### `keyword` — one word decides

A single word in the line carries the meaning, and a word that **sounds like
it** would change that meaning. The learner has to tell the two apart by ear.

Three tests. A turn that fails any of them is not a `keyword` turn.

**1. The pair must sound alike.** Not opposites in meaning — pairs that ears
actually confuse: twelve and twenty, thirteen and thirty, fifteen and fifty,
Tuesday and Thursday, fourteen and forty, Monday and Sunday, walk and work,
can and cat. `noon` and `night` are not such a pair. Neither are `better` and
`worse`: they mean the opposite, and sound nothing alike, so nothing is being
heard — only understood.

**2. The line must not contain the other word.** "Can we talk at three
instead of two?" names both, so anyone who caught the sentence knows which is
which. There is nothing left to mishear. Put the key word in the line and
leave its pair out.

**3. Swapping them must still make sense.** Replace the key word with its
pair and read the line again. It has to be something the same person could
plausibly have said in the same situation. If the swap turns the line into
nonsense, the learner rules the wrong reply out by reasoning rather than by
ear, and the turn measures nothing.

Test three is the one that catches the most. Do it on every `keyword` turn
before you output it.

```json
{
  "type": "keyword",
  "line": "The handover's on Thursday, so I'll need the file by Wednesday night.",
  "keyWord": "Thursday",
  "confusable": "Tuesday",
  "replies": [
    { "text": "Thursday — I'll have it ready the evening before.", "correct": true },
    { "text": "Got it, Tuesday. I'll finish up over the weekend, then.", "correct": false },
    { "text": "Is there any chance of another day? That week is full.", "correct": false }
  ],
  "restate": "It's the Thursday handover, so the file has to be in the night before.",
  "translations": { "line": "...", "replies": ["...", "...", "..."] }
}
```

**Do not write two replies that are the same sentence with one word changed.**
Change the wording as well, the way real people vary. Two near-identical
replies tell the learner that the answer is one of those two, and the third
becomes decoration.

### `polarity` — a reversing word decides

`not`, `can't`, `unless`, `without`, `never`, `hardly`. Miss it and the
meaning flips. This is where mishearing costs the most in real life.

**One of the two wrong replies must be the one a person who missed the
reversing word would naturally choose.** That is what makes a wrong answer
worth something: it says exactly what went wrong.

```json
{
  "type": "polarity",
  "line": "I won't be able to join unless the client call gets cancelled.",
  "keyWord": "unless",
  "confusable": "if",
  "replies": [
    { "text": "Understood — so only if that call drops off.", "correct": true },
    { "text": "Great, I'll save you a seat.", "correct": false },
    { "text": "Shall I move it to the afternoon instead?", "correct": false }
  ],
  "restate": "Only if that client call falls through can I make it.",
  "translations": { "line": "...", "replies": ["...", "...", "..."] }
}
```

### `multiFact` — two facts must both be caught

Time and place, person and place, day and time. The learner has to hold both
and check them.

**Each wrong reply drops exactly one of the facts, and says which one in
`missedSlot`.** A wrong answer then points at the thing that was missed, and
the same weakness can be practised again later.

Here the three replies *are* parallel in shape. That is correct for this
type: what differs is which fact was caught, and all three are natural
confirmations.

```json
{
  "type": "multiFact",
  "line": "Let's meet at the west exit at six, not the ticket gate.",
  "facts": [
    { "slot": "place", "value": "west exit", "confusable": "ticket gate" },
    { "slot": "time",  "value": "six",       "confusable": "seven" }
  ],
  "replies": [
    { "text": "West exit at six. See you then.", "correct": true },
    { "text": "Ticket gate at six — see you there.", "correct": false, "missedSlot": "place" },
    { "text": "West exit at seven, then.", "correct": false, "missedSlot": "time" }
  ],
  "restate": "Six o'clock, by the west exit — not the gate.",
  "translations": { "line": "...", "replies": ["...", "...", "..."] }
}
```

## RESTATE

Every turn carries a `restate`: what the person says when the learner misses
the moment to reply. **Say the same thing in different words.** Repeating the
sentence exactly would make it a second listen, which this practice does not
give.

## THE LINES THEMSELVES

- One to three sentences. Spoken English, not written English.
- Only what this person would actually hear in {SITUATION}.
- Invent nothing about the learner. No names of their colleagues, no
  companies, no facts you were not told.
- No brand names, no jargon, no idioms that only one country uses.
- The line must stand on its own. The learner has the situation and nothing
  else, so a line that needs earlier context is unusable.
- On a later turn the line may answer the reply the learner just gave, but it
  must still make sense whichever reply they chose.

## WINDOW

Each conversation carries `windowMs`: how long the learner has to reply,
after the line ends.

- A hurried exchange, someone on their way out: 2000
- Ordinary talk: 3000
- Unhurried, someone thinking aloud: 4000

**Vary it across the set.** The gap between turns is what real conversation
is made of; a fixed window would take that away.

## OUTPUT

```json
{
  "schema_version": "4.0",
  "type": "scenes",
  "native_language": "{NATIVE_LANGUAGE}",
  "scenes": [
    {
      "title": "Moving a deadline",
      "titleNative": "締め切りをずらす",
      "situation": "{SITUATION}",
      "settingNative": "午後のオフィスで、同僚から。",
      "windowMs": 3000,
      "turns": [ ... ]
    }
  ]
}
```

- `title` in English, `titleNative` in {NATIVE_LANGUAGE}.
- `settingNative` is one line of setting in {NATIVE_LANGUAGE}. Where they are,
  never who the other person is — that would give the answer away.
- `translations.line` and `translations.replies` in {NATIVE_LANGUAGE}. Natural
  translation, not word for word. The learner reads these only after answering.

## BEFORE YOU ANSWER

Go through every turn once more:

1. Hide the line. Can the three replies alone give the answer away? If yes,
   rewrite.
2. Are all three replies something a real person would say here?
3. `keyword` and `polarity`: are any two replies the same sentence with one
   word swapped? If yes, rewrite the wording.
4. `polarity`: does one wrong reply belong to someone who missed the
   reversing word?
5. `multiFact`: does each wrong reply drop exactly one fact, and name it?
6. Is `restate` different wording, not the same sentence?
7. Do the conversations vary in length, and the windows in size?
8. Did you invent anything about the learner that you were not told?

Output the JSON and nothing else.

--- END PROMPT ---

---

## 試作1回目で分かったこと（プロンプト修正の記録）

ChatGPT に貼って12往復を得た。結果は次のとおり。

- **目隠しテストは12往復すべて成立。** 読むだけで絞れる往復はなかった。
- **双子の返答はゼロ。**
- **`polarity` は4本とも正しい。** 誤答の一つが「反転語を聞き逃した人が選ぶもの」に
  なっていた。`hardly` を選んでいるのは良い判断。
- **`multiFact` は3本とも正しい。** `missedSlot` が落とした情報と一対一で対応していた。
- 往復数（1・2・4・3・2）と窓（2000〜4000）はどちらもばらけていた。

**`keyword` だけが5本中4本で外していた。**

| 台詞 | 対 | 何が起きたか |
|---|---|---|
| room twelve | twenty | 正しい |
| at three instead of two | two | 台詞が対の両方を含んでいる |
| before noon | night | 音が似ていない |
| first / second | first | 台詞が対の両方を含んでいる |
| went better | worse | 音が似ていない |

「意味を決める一語」は理解されたが、「**聞き違えうる一語**」にはなっていなかった。
外し方は二種類ある。台詞が対の両方を並べてしまう場合と、
意味の反対語を対にしてしまう場合。どちらも聞き分けを試していない。

そこで `keyword` の節に三つの検査を足した。音が似ていること、
台詞に対の相手を入れないこと、入れ替えても文が成立すること。
**三つ目が一番効く**。これを守れば残り二つもほぼ自動的に守られる。

`polarity` と `multiFact` は指示を変えていない。安定しているため。
