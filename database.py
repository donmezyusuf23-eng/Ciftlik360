import sqlite3
import os
from datetime import datetime, timedelta

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'ciftlik.db')

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    c = conn.cursor()

    # Kullanıcılar
    c.execute('''
    CREATE TABLE IF NOT EXISTS kullanicilar (
        kullanici_adi TEXT PRIMARY KEY,
        sifre TEXT NOT NULL,
        ciftlik_adi TEXT,
        telefon TEXT,
        gizli_soru TEXT,
        gizli_cevap TEXT,
        kayit_tarihi TEXT
    )
    ''')

    # Hayvanlar (Yetişkinler ve Genel Sürü)
    c.execute('''
    CREATE TABLE IF NOT EXISTS hayvanlar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kupe_no TEXT NOT NULL,
        isim TEXT,
        tur TEXT DEFAULT 'Sığır',
        cins TEXT,
        cinsiyet TEXT DEFAULT 'Dişi',
        dogum_tarihi TEXT,
        durum TEXT DEFAULT 'Aktif', -- Aktif, Satıldı, Kesildi, Öldü
        kullanici_adi TEXT NOT NULL,
        olusturma_tarihi TEXT
    )
    ''')

    # Buzağılar / Yavrular
    c.execute('''
    CREATE TABLE IF NOT EXISTS buzagilar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kupe_no TEXT NOT NULL,
        isim TEXT,
        dogum_tarihi TEXT NOT NULL,
        cinsiyet TEXT NOT NULL,
        cins TEXT,
        anne_adi TEXT,
        anne_kupe_no TEXT,
        baba_kupe_no TEXT,
        dogum_agirligi REAL,
        durum TEXT DEFAULT 'Aktif',
        kullanici_adi TEXT NOT NULL,
        olusturma_tarihi TEXT
    )
    ''')

    # Aşı & Sağlık Takibi
    c.execute('''
    CREATE TABLE IF NOT EXISTS asi_takip (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hayvan_kupe TEXT NOT NULL,
        hayvan_adi TEXT,
        asi_adi TEXT NOT NULL,
        planlanan_tarih TEXT NOT NULL,
        yapilis_tarihi TEXT,
        durum TEXT DEFAULT 'Yapılmadı', -- Yapılmadı, Yapıldı, İptal
        notlar TEXT,
        kullanici_adi TEXT NOT NULL,
        olusturma_tarihi TEXT
    )
    ''')

    # Günlük Süt Verim Takibi (Yeni Kritik Özellik)
    c.execute('''
    CREATE TABLE IF NOT EXISTS sut_kayitlari (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hayvan_kupe TEXT, -- Boş ise çiftlik geneli toplam sağım
        tarih TEXT NOT NULL,
        sagim_vakti TEXT NOT NULL, -- Sabah, Akşam, Öğle
        litre REAL NOT NULL,
        yag_orani REAL,
        notlar TEXT,
        kullanici_adi TEXT NOT NULL,
        olusturma_tarihi TEXT
    )
    ''')

    # Tohumlama & Gebelik & Doğum Takibi (Yeni Kritik Özellik)
    c.execute('''
    CREATE TABLE IF NOT EXISTS gebelik_takip (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hayvan_kupe TEXT NOT NULL,
        hayvan_adi TEXT,
        tohumlama_tarihi TEXT NOT NULL,
        tohumlama_turu TEXT DEFAULT 'Suni Tohumlama', -- Suni, Tabii
        baba_irki TEXT,
        gebelik_kontrol_tarihi TEXT, -- Tohumlama + 45-60 gün
        kuruya_alma_tarihi TEXT,     -- Tohumlama + 220 gün
        tahmini_dogum_tarihi TEXT,   -- Tohumlama + 283 gün
        durum TEXT DEFAULT 'Tohumlandı', -- Tohumlandı, Gebe (Onaylı), Kuru Dönemde, Doğurdu, Boş Döndü
        notlar TEXT,
        kullanici_adi TEXT NOT NULL,
        olusturma_tarihi TEXT
    )
    ''')

    # Giderler (Yem, Veteriner, İlaç, Mazot vb.)
    c.execute('''
    CREATE TABLE IF NOT EXISTS giderler (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        gider_turu TEXT NOT NULL,
        miktar REAL,
        birim TEXT DEFAULT 'Adet/Kg',
        tutar REAL NOT NULL,
        tarih TEXT NOT NULL,
        aciklama TEXT,
        kullanici_adi TEXT NOT NULL,
        olusturma_tarihi TEXT
    )
    ''')

    # Gelirler (Süt Satışı, Hayvan Satışı, Gübre, Destekleme vb. - Yeni Kritik Özellik)
    c.execute('''
    CREATE TABLE IF NOT EXISTS gelirler (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        gelir_turu TEXT NOT NULL,
        miktar REAL,
        birim TEXT DEFAULT 'Litre/Adet',
        tutar REAL NOT NULL,
        tarih TEXT NOT NULL,
        alici TEXT,
        aciklama TEXT,
        kullanici_adi TEXT NOT NULL,
        olusturma_tarihi TEXT
    )
    ''')

    conn.commit()

    # Orijinal veritabanından veri aktarımı (varsa)
    migrate_from_original_if_needed(conn)

    conn.close()

def migrate_from_original_if_needed(conn):
    orig_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'ciftlik_original.db')
    if not os.path.exists(orig_path):
        return

    c = conn.cursor()
    # Zaten veri var mı kontrol et
    c.execute("SELECT COUNT(*) FROM kullanicilar")
    if c.fetchone()[0] > 0:
        return

    print("Orijinal veritabanından veriler aktarılıyor...")
    orig = sqlite3.connect(orig_path)
    orig.row_factory = sqlite3.Row
    oc = orig.cursor()

    # Kullanıcılar
    try:
        oc.execute("SELECT * FROM kullanicilar")
        for u in oc.fetchall():
            c.execute("""
                INSERT OR IGNORE INTO kullanicilar (kullanici_adi, sifre, ciftlik_adi, gizli_soru, gizli_cevap, kayit_tarihi)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (u['kullanici_adi'], u['sifre'], f"{u['kullanici_adi'].capitalize()} Çiftliği", 
                  u['gizli_soru'] if 'gizli_soru' in u.keys() else None,
                  u['gizli_cevap'] if 'gizli_cevap' in u.keys() else None,
                  datetime.now().strftime("%Y-%m-%d")))
    except Exception as e:
        print("Kullanıcı aktarımı hatası:", e)

    # Hayvanlar
    try:
        oc.execute("SELECT * FROM hayvanlar")
        for h in oc.fetchall():
            c.execute("""
                INSERT INTO hayvanlar (kupe_no, isim, cins, kullanici_adi, olusturma_tarihi)
                VALUES (?, ?, ?, ?, ?)
            """, (h['kupe_no'], h['isim'], h['cins'], h['kullanici_adi'] or 'cihan', datetime.now().strftime("%Y-%m-%d")))
    except Exception as e:
        print("Hayvan aktarımı hatası:", e)

    # Buzağılar
    try:
        oc.execute("SELECT * FROM buzagilar")
        for b in oc.fetchall():
            c.execute("""
                INSERT INTO buzagilar (kupe_no, isim, dogum_tarihi, cinsiyet, cins, anne_adi, anne_kupe_no, kullanici_adi, olusturma_tarihi)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (b['kupe_no'], 
                  b['isim'] if 'isim' in b.keys() else f"Buzağı {b['kupe_no']}",
                  b['dogum_tarihi'] or datetime.now().strftime("%Y-%m-%d"),
                  b['cinsiyet'] or 'Bilinmiyor',
                  b['cins'] if 'cins' in b.keys() else 'Simental',
                  b['anne_adi'] if 'anne_adi' in b.keys() else None,
                  b['anne_kupe_no'] if 'anne_kupe_no' in b.keys() else None,
                  b['kullanici_adi'] if 'kullanici_adi' in b.keys() and b['kullanici_adi'] else 'cihan',
                  datetime.now().strftime("%Y-%m-%d")))
    except Exception as e:
        print("Buzağı aktarımı hatası:", e)

    # Aşılar
    try:
        oc.execute("SELECT * FROM asi_takip")
        for a in oc.fetchall():
            kupe = a['hayvan_kupe'] if 'hayvan_kupe' in a.keys() and a['hayvan_kupe'] else str(a['hayvan_id'] if 'hayvan_id' in a.keys() else 'Bilinmiyor')
            c.execute("""
                INSERT INTO asi_takip (hayvan_kupe, asi_adi, planlanan_tarih, durum, kullanici_adi, olusturma_tarihi)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (kupe, a['asi_adi'], a['planlanan_tarih'] or datetime.now().strftime("%Y-%m-%d"),
                  a['durum'] or 'Yapılmadı', a['kullanici_adi'] if 'kullanici_adi' in a.keys() and a['kullanici_adi'] else 'cihan',
                  datetime.now().strftime("%Y-%m-%d")))
    except Exception as e:
        print("Aşı aktarımı hatası:", e)

    # Giderler
    try:
        oc.execute("SELECT * FROM yem_gider")
        for g in oc.fetchall():
            c.execute("""
                INSERT INTO giderler (gider_turu, miktar, tutar, tarih, kullanici_adi, olusturma_tarihi)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (g['gider_turu'], g['miktar'], g['tutar'], g['tarih'] or datetime.now().strftime("%Y-%m-%d"),
                  g['kullanici_adi'] if 'kullanici_adi' in g.keys() and g['kullanici_adi'] else 'cihan',
                  datetime.now().strftime("%Y-%m-%d")))
    except Exception as e:
        print("Gider aktarımı hatası:", e)

    conn.commit()
    orig.close()
    print("Aktarım tamamlandı!")

if __name__ == '__main__':
    init_db()
    print("Veritabanı hazır.")
