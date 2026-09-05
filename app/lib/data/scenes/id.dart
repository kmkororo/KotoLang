/// Bahasa Indonesia: topik, situasi, terjemahan kalimat, tiga pilihan ①, serta
/// terjemahan dan alasan tiap jawaban ②. Jawaban benar selalu di depan.
library;

const Map<String, Map<String, dynamic>> id = {
  'builtin_w1': {
    'topic': 'Menolak permintaan',
    'setting': 'Seorang rekan meminta Anda menggantikan presentasinya hari Jumat',
    'ex': [
      {
        'line': 'Jumat sore kamu ada waktu? Aku punya dua rapat di jam yang sama. Bisa gantikan aku presentasi ke klien jam tiga?',
        'gist': [
          'Dia ingin Anda yang presentasi Jumat jam tiga',
          'Dia ingin Anda ikut rapat bersamanya Jumat jam tiga',
          'Dia bilang Anda boleh libur Jumat sore',
        ],
        'native': [
          'Jumat jam tiga susah buatku, laporanku jatuh tempo saat itu. Bisa minta klien pindah ke Senin?',
          'Tentu, aku duduk di sampingmu dan mencatat.',
          'Terima kasih! Kalau begitu aku libur Jumat sore.',
        ],
        'why': [
          'Menerima permintaan sebagai permintaan dan menawarkan jalan lain',
          'Mendengar "gantikan aku" sebagai "temani aku"',
          'Mendengar permintaan sebagai izin untuk libur',
        ],
      },
      {
        'line': 'Senin terlalu lambat, kliennya pergi hari Sabtu. Bisa ambil sepuluh menit pertama saja? Setelah itu aku masuk lewat telepon.',
        'gist': [
          'Hanya sepuluh menit pertama; setelah itu dia masuk lewat telepon',
          'Seluruh presentasi; dia tidak bisa hadir',
          'Dipindah ke Senin dan mulai sepuluh menit lebih awal',
        ],
        'native': [
          'Oke, sepuluh menit aku bisa. Kirim slide pertamanya, dan telepon jam tiga lewat sepuluh.',
          'Seluruh presentasi? Maaf, itu aku tidak bisa.',
          'Senin boleh. Kita mulai sepuluh menit lebih awal.',
        ],
        'why': [
          'Menerima "sepuluh menit, lalu lewat telepon" seperti yang dikatakan',
          'Mendengar "sepuluh menit pertama" sebagai "seluruh presentasi"',
          'Melewatkan "Senin terlalu lambat"',
        ],
      },
    ],
  },
  'builtin_w2': {
    'topic': 'Memindahkan rapat',
    'setting': 'Atasan Anda menanyakan soal memindahkan rapat minggu depan',
    'ex': [
      {
        'line': 'Bisa kita pindahkan rapat tim minggu depan? Kamis sudah tidak cocok untukku. Bagaimana kalau Jumat pagi jam sembilan?',
        'gist': [
          'Memindahkan rapat Kamis ke Jumat jam sembilan',
          'Memindahkan rapat Jumat ke Kamis jam sembilan',
          'Membatalkan rapat minggu depan',
        ],
        'native': [
          'Jumat jam sembilan cocok untuk saya. Saya kabari yang lain.',
          'Kamis jam sembilan tidak masalah untuk saya.',
          'Minggu depan tidak ada rapat? Saya tidak keberatan.',
        ],
        'why': [
          'Menerima "ke Jumat jam sembilan" seperti yang dikatakan',
          'Menukar Kamis dan Jumat',
          'Mendengar "pindahkan" sebagai "batalkan"',
        ],
      },
      {
        'line': 'Bagus. Satu lagi, bisa pesan ruang kecil? Yang besar sudah terpakai hari Jumat.',
        'gist': [
          'Pesan ruang kecil; yang besar terpakai hari Jumat',
          'Pesan ruang besar; yang kecil terpakai',
          'Dia yang memesan ruangnya; tidak perlu apa-apa',
        ],
        'native': [
          'Tentu, saya pesan ruang kecil untuk Jumat jam sembilan.',
          'Oke, saya pesan ruang besar.',
          'Bagus, jadi Bapak yang pesan ruangnya. Terima kasih!',
        ],
        'why': [
          'Menerima "kamu pesan yang kecil" seperti yang dikatakan',
          'Menukar besar dan kecil',
          'Mendengar permintaan sebagai sesuatu yang akan dilakukan orang lain',
        ],
      },
    ],
  },
  'builtin_w3': {
    'topic': 'Mengakui kesalahan',
    'setting': 'Atasan Anda, soal daftar harga yang Anda kirim ke klien',
    'ex': [
      {
        'line': 'Aku dapat email dari klien. Mereka bilang angka di daftar harganya salah. File mana yang kamu kirim?',
        'gist': [
          'Klien bilang angkanya salah; file mana yang Anda kirim?',
          'Klien bilang daftar harganya belum sampai',
          'Klien suka daftar harganya',
        ],
        'native': [
          'Maaf, saya rasa saya mengirim file lama. Saya cek sekarang dan kirim yang benar.',
          'Belum sampai? Saya kirim lagi sekarang.',
          'Terima kasih! Senang mereka menyukainya.',
        ],
        'why': [
          'Menjawab kesalahan dan pertanyaan soal file',
          'Mendengar "angka salah" sebagai "belum sampai"',
          'Mendengar keluhan sebagai pujian',
        ],
      },
      {
        'line': 'Jangan kirim apa pun dulu. Perbaiki filenya, tunjukkan ke aku dulu, lalu kita kirim bersama.',
        'gist': [
          'Jangan kirim dulu; perbaiki, tunjukkan ke atasan dulu, lalu kirim bersama',
          'Kirim ulang sekarang; lapor ke atasan nanti',
          'Atasan yang memperbaiki dan mengirim; tidak perlu apa-apa',
        ],
        'native': [
          'Mengerti. Saya perbaiki dan tunjukkan ke Bapak sebelum dikirim.',
          'Oke, saya kirim file barunya sekarang.',
          'Terima kasih sudah memperbaikinya untuk saya.',
        ],
        'why': [
          'Menerima "jangan dulu, tunjukkan dulu" seperti yang dikatakan',
          'Melewatkan "jangan kirim apa pun dulu"',
          'Mendengar "kamu perbaiki" sebagai "aku perbaiki"',
        ],
      },
    ],
  },
  'builtin_w4': {
    'topic': 'Diminta lembur',
    'setting': 'Sesaat sebelum jam pulang, seorang rekan',
    'ex': [
      {
        'line': 'Maaf minta ini, tapi bisa tinggal satu jam lagi malam ini? Klien memajukan tenggatnya ke besok pagi.',
        'gist': [
          'Tinggal satu jam lagi malam ini; tenggat maju ke besok pagi',
          'Datang satu jam lebih awal besok; tenggat besok sore',
          'Boleh pulang lebih awal; tenggat mundur ke minggu depan',
        ],
        'native': [
          'Satu jam boleh. Mulai dari mana?',
          'Tentu, besok aku datang lebih awal. Jam berapa?',
          'Bagus, terima kasih! Sampai besok.',
        ],
        'why': [
          'Menerima "satu jam malam ini" dan mulai bergerak',
          'Mendengar "tinggal malam ini" sebagai "datang awal besok"',
          'Mendengar "tinggal" sebagai "boleh pulang"',
        ],
      },
      {
        'line': 'Terima kasih. Bisa cek angka di laporan sementara aku menyelesaikan slide? Cukup totalnya di halaman terakhir.',
        'gist': [
          'Cek total di halaman terakhir laporan',
          'Selesaikan slide; laporan dia yang kerjakan',
          'Baca seluruh laporan dari awal sampai akhir',
        ],
        'native': [
          'Oke, cukup total di halaman terakhir. Kalau ada yang aneh aku kabari.',
          'Oke, aku selesaikan slide-nya. Kirim yang sudah ada.',
          'Seluruh laporan? Itu lebih dari satu jam.',
        ],
        'why': [
          'Menerima "cukup totalnya" seperti yang dikatakan',
          'Menukar kedua tugas',
          'Mendengar "cukup totalnya" sebagai "seluruh laporan"',
        ],
      },
    ],
  },
  'builtin_w5': {
    'topic': 'Menerima masukan',
    'setting': 'Atasan Anda, soal laporan yang Anda serahkan',
    'ex': [
      {
        'line': 'Laporanmu bagus, tapi terlalu panjang. Tidak ada yang membaca halaman terakhir, padahal poin utamamu ada di sana.',
        'gist': [
          'Terlalu panjang; poin utama di halaman terakhir dan tidak dibaca',
          'Terlalu pendek; poin utamanya kurang',
          'Bagus, terutama halaman terakhirnya',
        ],
        'native': [
          'Baik. Saya taruh poin utama di halaman pertama dan buat lebih pendek.',
          'Saya tambah halaman dengan detail lebih banyak.',
          'Terima kasih! Halaman terakhir itu saya kerjakan keras.',
        ],
        'why': [
          'Menerima "terlalu panjang, poin utama di akhir" seperti yang dikatakan',
          'Mendengar "terlalu panjang" sebagai "terlalu pendek"',
          'Mendengar "tidak dibaca" sebagai "bagus"',
        ],
      },
      {
        'line': 'Bagus. Dan untuk para manajer, buat versi satu halaman. Mereka hanya punya lima menit untuk membacanya.',
        'gist': [
          'Versi satu halaman untuk manajer; mereka punya lima menit',
          'Versi lima halaman untuk manajer; waktunya banyak',
          'Manajer tidak perlu apa-apa',
        ],
        'native': [
          'Satu halaman untuk manajer, mengerti. Saya kirim besok.',
          'Lima halaman untuk manajer? Oke, saya tulis lebih banyak.',
          'Jadi manajer tidak perlu salinan. Mengerti.',
        ],
        'why': [
          'Menerima "satu halaman" seperti yang dikatakan',
          'Mendengar "satu halaman, lima menit" sebagai "lima halaman"',
          'Melewatkan "buat versi"',
        ],
      },
    ],
  },
  'builtin_t1': {
    'topic': 'Tip',
    'setting': 'Tagihan datang setelah makan malam di restoran',
    'ex': [
      {
        'line': 'Ini tagihannya. Sekadar info, tip belum termasuk. Kebanyakan orang memberi sekitar 18 persen.',
        'gist': [
          'Tip belum termasuk; sekitar 18% yang biasa',
          'Tip sudah termasuk; tidak perlu tambah',
          'Di restoran ini tidak ada tip',
        ],
        'native': [
          'Oke, terima kasih. Saya tambah 18 persen.',
          'Oh, sudah termasuk? Kalau begitu saya bayar ini saja.',
          'Tidak ada tip di sini? Bagus, terima kasih.',
        ],
        'why': [
          'Menerima "belum termasuk, 18%" seperti yang dikatakan',
          'Mendengar "belum termasuk" sebagai "sudah termasuk"',
          'Mendengar "beri tip" sebagai "tidak ada tip"',
        ],
      },
      {
        'line': 'Bisa ditambahkan di mesin kartu. Nanti mesinnya minta pilih persentase.',
        'gist': [
          'Ditambahkan di mesin kartu dengan memilih persentase',
          'Ditinggal tunai di meja',
          'Diberikan langsung ke pelayan',
        ],
        'native': [
          'Bagus, saya pilih 18 persen di mesin.',
          'Ada kembalian? Saya hanya punya uang besar.',
          'Ini, untuk Anda.',
        ],
        'why': [
          'Menerima "pilih di mesin" seperti yang dikatakan',
          'Mengira bayar tunai',
          'Mengira diberikan langsung',
        ],
      },
    ],
  },
  'builtin_t2': {
    'topic': 'Airnya gratis?',
    'setting': 'Baru duduk di restoran',
    'ex': [
      {
        'line': 'Mau air? Air botol tiga dolar, atau air keran gratis.',
        'gist': [
          'Air botol tiga dolar; air keran gratis',
          'Semua air gratis',
          'Semua air tiga dolar',
        ],
        'native': [
          'Air keran saja.',
          'Air botol saja, karena gratis.',
          'Tiga dolar untuk air keran? Tidak, terima kasih.',
        ],
        'why': [
          'Menerima "air keran gratis" dan memilih',
          'Yang gratis air keran: salah dengar',
          'Tiga dolar itu air botol: terbalik',
        ],
      },
      {
        'line': 'Baik. Dan sekadar info, dapurnya agak lambat malam ini. Makanan mungkin sekitar tiga puluh menit.',
        'gist': [
          'Makanan mungkin sekitar tiga puluh menit malam ini',
          'Tutup dalam tiga puluh menit, jadi harus cepat',
          'Makanan keluar dalam tiga menit',
        ],
        'native': [
          'Tidak apa-apa, kami tidak buru-buru.',
          'Tutup tiga puluh menit lagi? Kami pesan sekarang.',
          'Hanya tiga menit? Wah, cepat.',
        ],
        'why': [
          'Menerima "akan lama" seperti yang dikatakan',
          'Mendengar "dapur lambat" sebagai "tutup"',
          'Mendengar thirty (30) sebagai three (3)',
        ],
      },
    ],
  },
  'builtin_t3': {
    'topic': 'Tidak ada pemesanan di hotel',
    'setting': 'Check-in di meja depan hotel',
    'ex': [
      {
        'line': 'Maaf, saya tidak menemukan pemesanan atas nama Anda untuk malam ini. Mungkin untuk besok?',
        'gist': [
          'Pemesanan malam ini tidak ditemukan; ditanya apakah untuk besok',
          'Ada pemesanan malam ini; tunggu kamar disiapkan',
          'Ada pemesanan untuk besok, tapi malam ini penuh',
        ],
        'native': [
          'Seharusnya untuk malam ini. Ini email konfirmasinya, bisa cek nomor pemesanannya?',
          'Oke, saya tunggu di sini sampai kamarnya siap.',
          'Penuh malam ini? Bisa rekomendasikan hotel lain?',
        ],
        'why': [
          'Menjawab "tidak ditemukan, besok?" dengan bukti',
          'Mendengar "tidak ada pemesanan" sebagai "kamar disiapkan"',
          'Tidak ada yang bilang "penuh"',
        ],
      },
      {
        'line': 'Ah, ketemu. Pemesanannya dibatalkan karena kartu Anda tidak berfungsi. Masih ada kamar, tapi harga malam ini dua puluh dolar lebih mahal.',
        'gist': [
          'Dibatalkan karena kartu; masih ada kamar, dua puluh dolar lebih mahal',
          'Dibatalkan karena kartu; kamar sudah habis',
          'Pemesanan berlaku; harga sama',
        ],
        'native': [
          'Kartu saya tidak berfungsi? Tidak ada yang memberi tahu. Bisa saya bayar sekarang dengan harga awal?',
          'Kamar habis? Kalau begitu saya harus cari hotel lain.',
          'Harga sama? Bagus, saya bayar sekarang.',
        ],
        'why': [
          'Menerima "dibatalkan, ada kamar, lebih mahal" dan meminta',
          'Mendengar "masih ada kamar" sebagai "habis"',
          'Melewatkan "dua puluh dolar lebih mahal"',
        ],
      },
    ],
  },
  'builtin_t4': {
    'topic': 'Tidak ada air panas',
    'setting': 'Shower tidak ada air panas; Anda menelepon meja depan',
    'ex': [
      {
        'line': 'Maaf soal air panasnya. Saya bisa kirim orang untuk memperbaiki dalam sekitar tiga puluh menit, atau pindahkan Anda ke kamar lain sekarang.',
        'gist': [
          'Perbaikan dalam tiga puluh menit, atau pindah kamar sekarang',
          'Perbaikan besok; tidak bisa pindah kamar',
          'Perbaikan sekarang juga; tidak perlu pindah',
        ],
        'native': [
          'Saya tunggu perbaikannya, terima kasih. Tiga puluh menit tidak masalah.',
          'Besok? Terlalu lambat. Saya butuh air panas malam ini.',
          'Sekarang? Bagus, saya tunggu di pintu.',
        ],
        'why': [
          'Menerima "perbaikan tiga puluh menit atau pindah sekarang" dan memilih',
          'Mendengar "tiga puluh menit" sebagai "besok"',
          'Yang "sekarang" itu pindah kamar, bukan perbaikan',
        ],
      },
      {
        'line': 'Baik. Sambil menunggu, Anda bisa pakai kolam renang di atap. Buka sampai jam sepuluh.',
        'gist': [
          'Sambil menunggu, kolam di atap buka sampai jam sepuluh',
          'Kolamnya tutup hari ini',
          'Kolamnya buka jam sepuluh',
        ],
        'native': [
          'Bagus, saya ke kolam saja. Telepon kamar saya kalau sudah diperbaiki.',
          'Kolamnya tutup? Oke, saya di kamar saja.',
          'Buka jam sepuluh? Terlalu malam untuk saya.',
        ],
        'why': [
          'Menerima "buka sampai jam sepuluh" seperti yang dikatakan',
          'Mendengar "buka" sebagai "tutup"',
          'Mendengar "sampai jam sepuluh" sebagai "mulai jam sepuluh"',
        ],
      },
    ],
  },
  'builtin_t5': {
    'topic': 'Harga di kasir berbeda',
    'setting': 'Di kasir dengan barang yang di rak tertulis diskon 20%',
    'ex': [
      {
        'line': 'Totalnya empat puluh delapan dolar lima puluh sen. Diskon dua puluh persen hanya untuk anggota, jadi belum termasuk.',
        'gist': [
          'Total 48,50; diskon 20% hanya anggota, belum termasuk',
          'Total 48,50; diskon 20% sudah masuk',
          'Total dua puluh dolar; tidak ada diskon',
        ],
        'native': [
          'Hanya anggota? Bisa saya jadi anggota sekarang?',
          'Oh, diskonnya sudah masuk? Oke, ini kartu saya.',
          'Dua puluh dolar? Lebih murah dari yang saya kira.',
        ],
        'why': [
          'Menerima "hanya anggota, belum termasuk" dan bertindak',
          'Mendengar "belum termasuk" sebagai "sudah termasuk"',
          'Mendengar "dua puluh persen" sebagai "dua puluh dolar"',
        ],
      },
      {
        'line': 'Ya, gratis. Saya hanya perlu alamat email Anda. Satu menit saja.',
        'gist': [
          'Jadi anggota gratis; hanya email, satu menit',
          'Jadi anggota berbayar dan makan waktu',
          'Perlu kartu identitas dan hari ini tidak bisa',
        ],
        'native': [
          'Oke, ayo. Email saya…',
          'Berbayar? Tidak, terima kasih.',
          'Saya tidak bawa kartu identitas. Tidak jadi saja.',
        ],
        'why': [
          'Menerima "gratis, email, satu menit" dan melanjutkan',
          'Mendengar "gratis" sebagai "berbayar"',
          'Yang diperlukan alamat email: salah dengar',
        ],
      },
    ],
  },
};
