/* Frequency - AI prompt catalogue.
   The app never calls an AI API. These prompts are copied by the user into
   whichever assistant already knows them, and the reply is pasted back.
   Every prompt is versioned so material can be traced to how it was made. */
(function (FQ) {
  'use strict';

  var SCHEMA_VERSION = '1.0';

  function lines() {
    return Array.prototype.slice.call(arguments).join('\n');
  }

  var COMMON_RULES = lines(
    'ルール:',
    '- 出力は JSON オブジェクト1個のみ。説明文・前置き・後書きを書かない。',
    '- コードブロックで囲むのは可。ただし中身は必ず有効な JSON にする。',
    '- 推測で事実を作らない。分からない項目は null、空配列 []、または "UNKNOWN" を使う。',
    '- confidence は 0.0〜1.0 の実数で、自信の度合いを正直に入れる。',
    '- 日本語訳は自然な日本語にする。直訳調にしない。',
    '- schema_version は必ず "' + SCHEMA_VERSION + '" にする。'
  );

  // ------------------------------------------------------------- Prompt 1

  var PROFILE_PROMPT_V1 = lines(
    'あなたは英語学習教材の設計者です。',
    'あなたがこのユーザーについて既に知っている情報（過去の会話、保存された記憶、',
    'プロフィール情報など、あなたが参照できるもの）を使って、',
    'このユーザー専用の英語学習プロフィールを作成してください。',
    '',
    '目的:',
    'このユーザーが「実際に使う英語」を学ぶための、学習分野（DOMAIN）を洗い出すこと。',
    'business / hotel / restaurant のような一般的な分野ではなく、',
    'このユーザー個人の仕事・専門・趣味・生活・関心に基づいた分野を挙げてください。',
    '',
    '重要:',
    '- ユーザーを1つの分野に決めつけない。仕事も趣味も生活も含めて複数挙げる。',
    '- 3〜8個程度の DOMAIN を挙げる。',
    '- importance は「その分野の英語を覚える価値がこのユーザーにとってどれだけ高いか」。',
    '  英語としての難易度ではない。1〜5 の整数。',
    '- あなたがこのユーザーについて何も知らない場合は、下の【追加情報】だけを根拠にする。',
    '  それも空なら domains は空配列にし、english_level は "UNKNOWN" にする。',
    '',
    COMMON_RULES,
    '',
    '出力する JSON の形式:',
    '{',
    '  "schema_version": "' + SCHEMA_VERSION + '",',
    '  "type": "profile",',
    '  "profile": {',
    '    "english_level": "A1|A2|B1|B2|C1|C2|UNKNOWN",',
    '    "level_confidence": 0.0,',
    '    "roles": ["ユーザーの役割・職種（分かる範囲で）"],',
    '    "learning_priorities": ["英語を使う具体的な場面"],',
    '    "notes": "補足があれば。無ければ空文字"',
    '  },',
    '  "domains": [',
    '    {',
    '      "name": "英語での分野名 (例: Aircraft Structural Engineering)",',
    '      "name_ja": "日本語での分野名 (例: 航空機構造設計)",',
    '      "importance": 5,',
    '      "confidence": 0.9,',
    '      "contexts": ["その分野で英語を使う場面を3〜6個"],',
    '      "sample_terms": ["その分野の代表的な英語表現を3〜8個"]',
    '    }',
    '  ]',
    '}',
    '',
    '【追加情報】(ユーザーが必要に応じて記入。空のままでも構いません)',
    '仕事:',
    '趣味:',
    'よく使う専門用語:',
    '英語を使う場面:',
    '英語レベル(分かれば):'
  );

  // ------------------------------------------------------------- Prompt 2

  function materialPrompt(ctx) {
    ctx = ctx || {};
    var domainName = ctx.domainName || '(ここに分野名)';
    var domainJa = ctx.domainJa || '';
    var level = ctx.level || 'B1';
    var roles = (ctx.roles && ctx.roles.length) ? ctx.roles.join(', ') : '(不明)';
    var priorities = (ctx.priorities && ctx.priorities.length) ? ctx.priorities.join(', ') : '(不明)';
    var contexts = (ctx.contexts && ctx.contexts.length) ? ctx.contexts.join(', ') : '(指定なし)';
    var existing = (ctx.existingItems && ctx.existingItems.length)
      ? ctx.existingItems.slice(0, 120).join(', ')
      : '(なし)';

    return lines(
      'あなたは英語学習教材の作成者です。',
      '以下のユーザー向けに、指定された1つの分野の英語教材を作成してください。',
      '',
      '【ユーザー情報】',
      '英語レベル(CEFR): ' + level,
      '役割: ' + roles,
      '英語を使う場面: ' + priorities,
      '',
      '【対象分野】',
      '分野: ' + domainName + (domainJa ? ' (' + domainJa + ')' : ''),
      '想定される場面: ' + contexts,
      '',
      '【既に登録済みの表現（重複させないでください）】',
      existing,
      '',
      '【作るもの】',
      '1. learning_items: この分野で実際に使う英語表現。50〜100個。',
      '   専門用語だけでなく、その分野の会話で頻出する動詞句・コロケーションも含める。',
      '2. sentences: learning_items を自然に使った英文。80〜120個。',
      '',
      '【品質の要件 - 最重要】',
      '- 英文は文法的に正しく、その分野の人が実際に口にする自然な英語であること。',
      '- 専門用語を無理に詰め込んだ不自然な文を作らない。1文に対象表現は1〜2個まで。',
      '- リスニング教材なので、聞いて理解できる長さにする。1文 6〜18語程度。',
      '- 同じ文の単語を入れ替えただけの水増しをしない。',
      '- 場面を多様にする。statement / question / request / confirmation /',
      '  explanation / report / warning / opinion / instruction / discussion を混ぜる。',
      '- CEFR ' + level + ' を目安にする。専門用語が難しくても、文構造まで不必要に難しくしない。',
      '- 1つの learning_item に対して、異なる場面の英文を2〜3個作る。',
      '- 内容が薄い分野なら、無理に数を埋めずに減らしてよい。',
      '',
      '【distractors_ja について】',
      'アプリは4択問題を自動生成します。各 learning_item に、',
      '「意味は違うが同じ分野でありそうな日本語」を3個ずつ入れてください。',
      '正解と紛らわしすぎて複数正解になるものは入れないこと。',
      '',
      '【paraphrase_en / paraphrase_options_en について - 重要】',
      '各 sentence に、その文の趣旨を別の言い方で表した英文を1つ（paraphrase_en）と、',
      '「趣旨として惜しいが間違い」の英文を3つ（paraphrase_options_en）入れてください。',
      'これは「聞こえた英文の趣旨に最も近い英文はどれか」という4択に使います。',
      '',
      '守ってほしいこと:',
      '  - paraphrase_en は元の文と同じ意味だが、別の語彙・構文で言い換える。',
      '  - 元の文に出てくる対象表現をそのまま含めない。含めると文字合わせで解けてしまう。',
      '  - 4つの英文は長さ・語彙レベルをそろえる。1つだけ長い/短いと形で見分けられる。',
      '  - 誤答は、肯定否定・主体・時制・条件・強さのいずれかだけを変えて作る。',
      '  - 誤答に元の文と同じ意味のものを入れない（複数正解になります）。',
      '  - CEFR ' + level + ' 前後の自然な英語にする。',
      '',
      '例:',
      '  text: "Do not sign off until the supplier confirms it."',
      '  paraphrase_en: "Wait until the supplier has confirmed it before approving."',
      '  paraphrase_options_en: [',
      '    "Approve it now and let the supplier confirm afterwards.",',
      '    "Ask the supplier to approve it on your behalf.",',
      '    "You may approve it without waiting for the supplier."',
      '  ]',
      '',
      '【meaning_options_ja について - 重要】',
      '各 sentence に、「聞き取った内容の意味として、惜しいが間違い」の日本語を3個入れてください。',
      'これはリスニングの内容理解問題に使います。難しくすることが目的です。',
      '良い誤答の作り方（1文につき異なる観点を混ぜる）:',
      '  - 肯定と否定を入れ替える（必要がある → 必要はない）',
      '  - 主体を入れ替える（こちらが確認する → 先方が確認する）',
      '  - 時制・完了を変える（更新された → これから更新する）',
      '  - 強さを変える（必ず必要 → できれば望ましい）',
      '  - 条件を足す/外す（無条件 → 承認された場合のみ）',
      '悪い誤答: 全く別の話題、明らかに無関係な内容。それでは簡単すぎます。',
      '正解の translation_ja と同じ意味になる選択肢は絶対に入れないこと（複数正解になります）。',
      '',
      COMMON_RULES,
      '',
      '出力する JSON の形式:',
      '{',
      '  "schema_version": "' + SCHEMA_VERSION + '",',
      '  "type": "material",',
      '  "domain": {',
      '    "name": "' + domainName + '",',
      '    "name_ja": "日本語名",',
      '    "importance": 5,',
      '    "confidence": 0.9,',
      '    "contexts": ["場面"]',
      '  },',
      '  "learning_items": [',
      '    {',
      '      "text": "repair policy",',
      '      "type": "term|phrase|collocation|expression",',
      '      "meaning_ja": "修理方針",',
      '      "priority": 5,',
      '      "confidence": 0.9,',
      '      "related_terms": ["関連表現"],',
      '      "contexts": ["使われる場面"],',
      '      "distractors_ja": ["点検記録", "飛行計画", "設計基準"]',
      '    }',
      '  ],',
      '  "sentences": [',
      '    {',
      '      "text": "We need to review the repair policy before proceeding.",',
      '      "translation_ja": "先に進む前に、修理方針を確認する必要があります。",',
      '      "level": "B1",',
      '      "context": "design review",',
      '      "speech_act": "statement",',
      '      "targets": ["repair policy"],',
      '      "naturalness": 5,',
      '      "paraphrase_en": "We should go over the rules for repairs before moving on.",',
      '      "paraphrase_options_en": [',
      '        "We can move on without going over the rules for repairs.",',
      '        "The rules for repairs will be reviewed by someone else.",',
      '        "The rules for repairs were already reviewed last week."',
      '      ],',
      '      "meaning_options_ja": [',
      '        "先に進む前に修理方針を確認する必要はありません。",',
      '        "修理方針は先方が確認することになっています。",',
      '        "修理方針の確認は、できれば済ませておきたい程度です。"',
      '      ]',
      '    }',
      '  ]',
      '}',
      '',
      '注意: targets には、その英文中に実際に現れる learning_items の text を',
      '完全一致で入れてください。英文に無い表現を targets に入れないこと。'
    );
  }

  // ------------------------------------------------------------- Prompt 3

  function auditPrompt(payload) {
    return lines(
      'あなたは英語教材の品質監査者です。',
      '以下の英文リストを厳しく評価してください。',
      '',
      '【評価項目】',
      '- Grammar: 文法的に正しいか',
      '- Naturalness: ネイティブが実際に使う自然な英語か',
      '- Domain relevance: その分野に関連しているか',
      '- Listening suitability: 音声で聞いて理解できるか',
      '- Ambiguity: 曖昧さや複数解釈の余地がないか',
      '- Difficulty: 指定レベルに対して適切か',
      '- Duplication: 他の文と実質的に重複していないか',
      '- Factual accuracy: 事実として誤っていないか',
      '',
      '【スコア】',
      '5 = そのまま使える',
      '4 = ほぼ問題なし',
      '3 = 使えるが改善余地あり',
      '2 = 不自然。修正が必要',
      '1 = 使うべきでない',
      '',
      COMMON_RULES,
      '',
      '出力する JSON の形式:',
      '{',
      '  "schema_version": "' + SCHEMA_VERSION + '",',
      '  "type": "audit",',
      '  "results": [',
      '    {',
      '      "text": "評価対象の英文をそのまま",',
      '      "score": 4,',
      '      "issues": ["問題点があれば簡潔に"],',
      '      "suggested_fix": "修正案。不要なら空文字"',
      '    }',
      '  ]',
      '}',
      '',
      '【評価対象の英文】',
      payload || '(ここに英文を貼り付け)'
    );
  }

  // ------------------------------------------------------------- Prompt 4

  function newDomainPrompt(ctx) {
    ctx = ctx || {};
    var existingDomains = (ctx.existingDomains && ctx.existingDomains.length)
      ? ctx.existingDomains.join(', ') : '(なし)';
    return lines(
      'あなたは英語学習教材の作成者です。',
      'このユーザーには既に以下の学習分野が登録されています。',
      '',
      '【登録済みの分野】',
      existingDomains,
      '',
      '【依頼】',
      '下の【新しい分野】に書かれた分野について、新たに教材を作成してください。',
      '既存の分野と内容が重複しないようにしてください。',
      '既存分野で既に扱われている表現は避け、この分野に固有の表現を中心にしてください。',
      '',
      '英語レベル(CEFR): ' + (ctx.level || 'B1'),
      '',
      '作るものと品質要件、および出力形式は、',
      '通常の教材生成と同じ「material」形式に従ってください。',
      '',
      '- learning_items: 50〜100個',
      '- sentences: 80〜120個',
      '- 1文 6〜18語、場面を多様に、水増し禁止',
      '- targets には英文中に実際に現れる表現のみを完全一致で入れる',
      '- 各 learning_item に distractors_ja を3個',
      '- 各 sentence に paraphrase_en（言い換えた英文）と paraphrase_options_en を3個',
      '- 各 sentence に meaning_options_ja（惜しいが間違いの日本語）を3個',
      '',
      COMMON_RULES,
      '',
      '出力する JSON の形式:',
      '{',
      '  "schema_version": "' + SCHEMA_VERSION + '",',
      '  "type": "material",',
      '  "domain": { "name": "", "name_ja": "", "importance": 3, "confidence": 0.8, "contexts": [] },',
      '  "learning_items": [ { "text": "", "type": "term", "meaning_ja": "", "priority": 3,',
      '      "confidence": 0.8, "related_terms": [], "contexts": [], "distractors_ja": [] } ],',
      '  "sentences": [ { "text": "", "translation_ja": "", "level": "B1", "context": "",',
      '      "speech_act": "statement", "targets": [], "naturalness": 5,',
      '      "paraphrase_en": "同じ意味を別の言い方で表した英文",',
      '      "paraphrase_options_en": ["惜しいが誤りの英文1", "英文2", "英文3"],',
      '      "meaning_options_ja": ["惜しいが誤り1", "惜しいが誤り2", "惜しいが誤り3"] } ]',
      '}',
      '',
      '【新しい分野】',
      ctx.newDomain || '(ここに追加したい分野を書いてください。例: Travel / 旅行)'
    );
  }

  FQ.prompts = {
    SCHEMA_VERSION: SCHEMA_VERSION,
    versions: {
      profile: 'PROFILE_PROMPT_V1',
      material: 'MATERIAL_PROMPT_V1',
      audit: 'AUDIT_PROMPT_V1',
      domain: 'DOMAIN_PROMPT_V1'
    },
    profile: function () { return PROFILE_PROMPT_V1; },
    material: materialPrompt,
    audit: auditPrompt,
    newDomain: newDomainPrompt
  };

})(window.FQ = window.FQ || {});
