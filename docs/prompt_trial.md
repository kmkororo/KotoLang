# 生成の試作（フェーズ2a）

新形式が成立するかを判定するための試作。3本の“会話”を書いた。
型は3つとも入れ、往復数と窓の長さを変えてある。

**判定のしかた。** 下の「目隠しテスト」を先に読み、返答3つだけを見て
正解が分かってしまわないかを確かめる。分かってしまうなら形式が成立していない。

そのうえで `docs/prompt_scenes_v2.md` のプロンプトを ChatGPT / Gemini に貼り、
同じ質のものが安定して返るかを確かめる。**そちらが本番の関門。**
ここにある試作は「目標がどの水準か」を示すためのもの。

---

## 目隠しテスト

台詞を見ずに、返答3つだけを読む。どれが正解か分かるだろうか。

**1.** 場面：職場の廊下。急いでいる相手に呼び止められた。

- 「2時までですね。机に置いておきます」
- 「10時までですか。厳しいですが、やってみます」
- 「できますが、最新の数字がまだ来ていません」

**2.** 場面：電話。訪問の予定について。

- 「では昼のあとしか無理ということですね。動かせるか見てみます」
- 「よかった、午前に伺うと伝えておきます」
- 「大丈夫です、こちらだけで行きます」

**3.** 場面：待ち合わせの確認。

- 「紙の図面、4号室ですね。承知しました」
- 「タブレットで4号室ですね。了解です」
- 「紙の図面で、3号室ですね」

どれも、それだけ読んでは決まらない。3つとも会話として成り立っている。
これが成立していれば形式は機能する。

---

## 試作 1 ・ 1往復・窓2000ms・keyword

```json
{
  "title": "Figures before the meeting",
  "titleNative": "会議前の数字",
  "situation": "work",
  "settingNative": "職場の廊下で、急いでいる相手から。",
  "windowMs": 2000,
  "turns": [
    {
      "type": "keyword",
      "line": "Quick one — can you get me the figures before the two o'clock?",
      "keyWord": "two",
      "confusable": "ten",
      "replies": [
        { "text": "Before two, sure. I'll drop them on your desk.", "correct": true },
        { "text": "Before ten? That's tight, but I'll try.", "correct": false },
        { "text": "I can, but the latest numbers aren't in yet.", "correct": false }
      ],
      "restate": "Sorry — the figures, before we start at two.",
      "translations": {
        "line": "急ぎで一つ。2時のに間に合うように数字をもらえますか。",
        "replies": [
          "2時までですね。机に置いておきます。",
          "10時までですか。厳しいですが、やってみます。",
          "できますが、最新の数字がまだ来ていません。"
        ]
      }
    }
  ]
}
```

---

## 試作 2 ・ 3往復・窓3000ms・polarity → keyword → multiFact

```json
{
  "title": "Rearranging a site visit",
  "titleNative": "現場訪問の組み直し",
  "situation": "work",
  "settingNative": "電話で。訪問の予定について。",
  "windowMs": 3000,
  "turns": [
    {
      "type": "polarity",
      "line": "I can't make the site visit unless we push it past lunch.",
      "keyWord": "unless",
      "confusable": "if",
      "replies": [
        { "text": "So after lunch is the only way. Let me see what I can move.", "correct": true },
        { "text": "Perfect — I'll tell them you're coming this morning.", "correct": false },
        { "text": "No problem, I'll go on my own then.", "correct": false }
      ],
      "restate": "Only a slot after lunch would work for me.",
      "translations": {
        "line": "昼のあとにずらせないと、現場訪問には行けません。",
        "replies": [
          "では昼のあとしか無理ということですね。動かせるか見てみます。",
          "よかった、午前に伺うと伝えておきます。",
          "大丈夫です、こちらだけで行きます。"
        ]
      }
    },
    {
      "type": "keyword",
      "line": "I'll come straight from the station, so I'll be at the back entrance.",
      "keyWord": "back",
      "confusable": "front",
      "replies": [
        { "text": "Back entrance — I'll let the desk know to expect you there.", "correct": true },
        { "text": "I'll meet you out front, then.", "correct": false },
        { "text": "Do you want me to send someone down?", "correct": false }
      ],
      "restate": "I'll be coming round to the entrance at the back.",
      "translations": {
        "line": "駅からそのまま行くので、裏の入口に着きます。",
        "replies": [
          "裏口ですね。受付にそう伝えておきます。",
          "では表で待ち合わせましょう。",
          "誰か下まで行かせましょうか。"
        ]
      }
    },
    {
      "type": "multiFact",
      "line": "Bring the printed plans, not the tablet — and come to room four, not three.",
      "facts": [
        { "slot": "item", "value": "printed plans", "confusable": "tablet" },
        { "slot": "room", "value": "four", "confusable": "three" }
      ],
      "replies": [
        { "text": "Printed plans, room four. Got it.", "correct": true },
        { "text": "Tablet, room four — understood.", "correct": false, "missedSlot": "item" },
        { "text": "Printed plans, room three, then.", "correct": false, "missedSlot": "room" }
      ],
      "restate": "Paper copies please, and it's the fourth room, not the third.",
      "translations": {
        "line": "タブレットではなく紙の図面を持ってきてください。部屋は3号室ではなく4号室です。",
        "replies": [
          "紙の図面、4号室ですね。承知しました。",
          "タブレットで4号室ですね。了解です。",
          "紙の図面で、3号室ですね。"
        ]
      }
    }
  ]
}
```

---

## 試作 3 ・ 2往復・窓4000ms・keyword → polarity

```json
{
  "title": "That place by the river",
  "titleNative": "川沿いのあの店",
  "situation": "daily",
  "settingNative": "昼休みの雑談で。",
  "windowMs": 4000,
  "turns": [
    {
      "type": "keyword",
      "line": "I finally got round to that place you mentioned — the one by the river.",
      "keyWord": "river",
      "confusable": "station",
      "replies": [
        { "text": "Oh, by the river? What did you think of it?", "correct": true },
        { "text": "The one near the station — did you like it?", "correct": false },
        { "text": "Good, I've been meaning to go back there myself.", "correct": false }
      ],
      "restate": "That spot down by the water, I mean.",
      "translations": {
        "line": "前に言ってた店、やっと行ってきました。川沿いのほうです。",
        "replies": [
          "川沿いのほうですか。どうでした？",
          "駅の近くのですね。よかったですか？",
          "いいですね、私ももう一度行きたいと思っていました。"
        ]
      }
    },
    {
      "type": "polarity",
      "line": "I wouldn't go on a weekend, though — you'd never get a table.",
      "keyWord": "wouldn't",
      "confusable": "would",
      "replies": [
        { "text": "Weekdays it is, then.", "correct": true },
        { "text": "Saturday sounds good — I'll book us in.", "correct": false },
        { "text": "Is it worth the wait, though?", "correct": false }
      ],
      "restate": "Weekends are hopeless there — no chance of a table.",
      "translations": {
        "line": "ただ週末は行かないほうがいいです。席が取れませんから。",
        "replies": [
          "では平日にしましょう。",
          "土曜がよさそうですね。予約しておきます。",
          "待ってでも行く価値はありますか？"
        ]
      }
    }
  ]
}
```

---

## 試作を通して分かったこと

### ブリーフの例のままでは形式が壊れる

ブリーフの `keyword` の例は、返答が一語だけ違う双子になっている。

```
"Sure, four works for me."
"Sure, three works for me."
```

学習者は「答えはこの2つのどちらか」と即座に絞れる。実質2択であり、
「読むだけでは絞れない」という要件を満たさない。
プロンプトには**言い回しごと変えるよう明示的に禁止条項を入れた。**

`multiFact` だけは並行した形が必要なので、この禁止から除外している。
誤答が「どの情報を落としたか」と一対一に対応する必要があるため。
この場合も3つとも自然な確認の返事なので、読むだけでは絞れない。

### 「読むだけでは絞れない」を手続きに落とす必要がある

抽象的な指示のままだと AI が自己判定できない。
**「台詞を隠して返答3つだけを見て、正解が分かるか」** という具体的な手続きにすると、
自己点検できる。プロンプトの冒頭と末尾の両方に置いた。

### スキーマへの影響

試作の範囲では、ブリーフのスキーマ案をそのまま使える。変更の必要はなかった。
ただし次の2点は実装時に決める必要がある。

- `keyWord` と `confusable` は、いまのところ**生成時の指示と検証にしか使わない**。
  アプリ側では正解判定に使っていない（正解は `replies[].correct` で決まる）。
  取り込み時の検証に使うか、単なる記録として持つかを決める。
- `translations` を往復ごとに持つ形にした。ブリーフの例は
  `"translations": { "ja": "..." }` と言語コードを鍵にしていたが、
  取り込み時点で言語は1つに決まっているので、`line` と `replies` を直接持つ形にした。
