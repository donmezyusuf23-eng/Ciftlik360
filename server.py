import os
import socket
from datetime import datetime, timedelta
from typing import Optional, List
from fastapi import FastAPI, HTTPException, Depends, Query, Request
from fastapi.responses import HTMLResponse, JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import sqlite3

from database import get_db, init_db

app = FastAPI(title="Çiftlik 360 - Mobil Çiftlik Yönetim Sistemi")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Statik dosyalar için dizin oluştur
STATIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'static')
os.makedirs(STATIC_DIR, exist_ok=True)
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

# --- MODELLER ---
class LoginRequest(BaseModel):
    kullanici_adi: str
    sifre: str

class RegisterRequest(BaseModel):
    kullanici_adi: str
    sifre: str
    ciftlik_adi: Optional[str] = "Bizim Çiftlik"
    telefon: Optional[str] = None
    gizli_soru: Optional[str] = None
    gizli_cevap: Optional[str] = None

class AnimalCreate(BaseModel):
    kupe_no: str
    isim: Optional[str] = ""
    tur: Optional[str] = "Sığır"
    cins: Optional[str] = "Simental"
    cinsiyet: Optional[str] = "Dişi"
    dogum_tarihi: Optional[str] = None
    kullanici_adi: str

class CalfCreate(BaseModel):
    kupe_no: str
    isim: Optional[str] = ""
    dogum_tarihi: str
    cinsiyet: str
    cins: Optional[str] = "Simental"
    anne_adi: Optional[str] = None
    anne_kupe_no: Optional[str] = None
    baba_kupe_no: Optional[str] = None
    dogum_agirligi: Optional[float] = None
    kullanici_adi: str

class MilkCreate(BaseModel):
    hayvan_kupe: Optional[str] = ""
    tarih: str
    sagim_vakti: str # Sabah, Aksam, Ogle, Toplam
    litre: float
    yag_orani: Optional[float] = None
    notlar: Optional[str] = None
    kullanici_adi: str

class PregnancyCreate(BaseModel):
    hayvan_kupe: str
    hayvan_adi: Optional[str] = None
    tohumlama_tarihi: str
    tohumlama_turu: Optional[str] = "Suni Tohumlama"
    baba_irki: Optional[str] = None
    notlar: Optional[str] = None
    kullanici_adi: str

class VaccineCreate(BaseModel):
    hayvan_kupe: str
    hayvan_adi: Optional[str] = None
    asi_adi: str
    planlanan_tarih: str
    notlar: Optional[str] = None
    kullanici_adi: str

class ExpenseCreate(BaseModel):
    gider_turu: str
    miktar: Optional[float] = 1.0
    birim: Optional[str] = "Adet/Kg"
    tutar: float
    tarih: str
    aciklama: Optional[str] = None
    kullanici_adi: str

class IncomeCreate(BaseModel):
    gelir_turu: str
    miktar: Optional[float] = 1.0
    birim: Optional[str] = "Litre/Adet"
    tutar: float
    tarih: str
    alici: Optional[str] = None
    aciklama: Optional[str] = None
    kullanici_adi: str


# --- AUTH ENDPOINTS ---
@app.post("/api/login")
def login(req: LoginRequest):
    conn = get_db()
    c = conn.cursor()
    c.execute("SELECT * FROM kullanicilar WHERE LOWER(kullanici_adi) = LOWER(?)", (req.kullanici_adi,))
    user = c.fetchone()
    conn.close()

    if not user or user["sifre"] != req.sifre:
        raise HTTPException(status_code=401, detail="Kullanıcı adı veya şifre hatalı!")
    
    return {
        "status": "success",
        "user": {
            "kullanici_adi": user["kullanici_adi"],
            "ciftlik_adi": user["ciftlik_adi"] or f"{user['kullanici_adi'].capitalize()} Çiftliği",
            "telefon": user["telefon"]
        }
    }

@app.post("/api/register")
def register(req: RegisterRequest):
    conn = get_db()
    c = conn.cursor()
    try:
        c.execute("""
            INSERT INTO kullanicilar (kullanici_adi, sifre, ciftlik_adi, telefon, gizli_soru, gizli_cevap, kayit_tarihi)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (req.kullanici_adi.strip(), req.sifre, req.ciftlik_adi, req.telefon, req.gizli_soru, req.gizli_cevap, datetime.now().strftime("%Y-%m-%d")))
        conn.commit()
    except sqlite3.IntegrityError:
        conn.close()
        raise HTTPException(status_code=400, detail="Bu kullanıcı adı zaten alınmış!")
    conn.close()
    return {"status": "success", "message": "Kayıt başarılı!"}


# --- DASHBOARD & UYARILAR ---
@app.get("/api/dashboard/stats")
def get_dashboard_stats(user: str = Query("cihan")):
    conn = get_db()
    c = conn.cursor()
    today_str = datetime.now().strftime("%Y-%m-%d")
    this_month_prefix = datetime.now().strftime("%Y-%m")

    # Toplam yetişkin hayvan
    c.execute("SELECT COUNT(*) FROM hayvanlar WHERE LOWER(kullanici_adi)=LOWER(?) AND durum='Aktif'", (user,))
    toplam_yetiskin = c.fetchone()[0]

    # Toplam buzağı
    c.execute("SELECT COUNT(*) FROM buzagilar WHERE LOWER(kullanici_adi)=LOWER(?) AND durum='Aktif'", (user,))
    toplam_buzagi = c.fetchone()[0]

    # Aktif Gebe / Tohumlu sayısı
    c.execute("SELECT COUNT(*) FROM gebelik_takip WHERE LOWER(kullanici_adi)=LOWER(?) AND durum IN ('Tohumlandı', 'Gebe (Onaylı)', 'Kuru Dönemde')", (user,))
    aktif_gebe = c.fetchone()[0]

    # Bugün sağılan toplam süt (Litre)
    c.execute("SELECT SUM(litre) FROM sut_kayitlari WHERE LOWER(kullanici_adi)=LOWER(?) AND tarih=?", (user, today_str))
    bugun_sut = c.fetchone()[0] or 0.0

    # Bu ayki toplam gider
    c.execute("SELECT SUM(tutar) FROM giderler WHERE LOWER(kullanici_adi)=LOWER(?) AND tarih LIKE ?", (user, f"{this_month_prefix}%"))
    bu_ay_gider = c.fetchone()[0] or 0.0

    # Bu ayki toplam gelir
    c.execute("SELECT SUM(tutar) FROM gelirler WHERE LOWER(kullanici_adi)=LOWER(?) AND tarih LIKE ?", (user, f"{this_month_prefix}%"))
    bu_ay_gelir = c.fetchone()[0] or 0.0

    # Bekleyen / Geciken aşı sayısı
    c.execute("SELECT COUNT(*) FROM asi_takip WHERE LOWER(kullanici_adi)=LOWER(?) AND durum='Yapılmadı'", (user,))
    bekleyen_asi = c.fetchone()[0]

    conn.close()

    return {
        "toplam_hayvan": toplam_yetiskin + toplam_buzagi,
        "yetiskin_sayisi": toplam_yetiskin,
        "buzagi_sayisi": toplam_buzagi,
        "aktif_gebe_sayisi": aktif_gebe,
        "bugun_sut_litre": round(bugun_sut, 1),
        "bu_ay_gider": round(bu_ay_gider, 2),
        "bu_ay_gelir": round(bu_ay_gelir, 2),
        "bu_ay_net_kar": round(bu_ay_gelir - bu_ay_gider, 2),
        "bekleyen_asi_sayisi": bekleyen_asi
    }

@app.get("/api/dashboard/alerts")
def get_alerts(user: str = Query("cihan")):
    conn = get_db()
    c = conn.cursor()
    today = datetime.now().date()
    alerts = []

    # 1. Günü gelen / geciken aşılar
    c.execute("""
        SELECT * FROM asi_takip 
        WHERE LOWER(kullanici_adi)=LOWER(?) AND durum='Yapılmadı'
        ORDER BY planlanan_tarih ASC
    """, (user,))
    for a in c.fetchall():
        try:
            p_date = datetime.strptime(a["planlanan_tarih"], "%Y-%m-%d").date()
            diff = (p_date - today).days
            if diff < 0:
                alerts.append({
                    "id": a["id"],
                    "tip": "danger",
                    "baslik": "⚠️ Geciken Aşı!",
                    "mesaj": f"Küpe: {a['hayvan_kupe']} - {a['asi_adi']} aşısının vakti {abs(diff)} gün önce geçmiş!",
                    "kategori": "asi",
                    "tarih": a["planlanan_tarih"]
                })
            elif diff <= 7:
                alerts.append({
                    "id": a["id"],
                    "tip": "warning",
                    "baslik": "💉 Yaklaşan Aşı",
                    "mesaj": f"Küpe: {a['hayvan_kupe']} - {a['asi_adi']} aşısına {diff} gün kaldı ({a['planlanan_tarih']})",
                    "kategori": "asi",
                    "tarih": a["planlanan_tarih"]
                })
        except:
            pass

    # 2. Yaklaşan doğumlar (Gebelikte son 15 gün veya geçmiş)
    c.execute("""
        SELECT * FROM gebelik_takip
        WHERE LOWER(kullanici_adi)=LOWER(?) AND durum IN ('Tohumlandı', 'Gebe (Onaylı)', 'Kuru Dönemde')
    """, (user,))
    for g in c.fetchall():
        if g["tahmini_dogum_tarihi"]:
            try:
                d_date = datetime.strptime(g["tahmini_dogum_tarihi"], "%Y-%m-%d").date()
                diff = (d_date - today).days
                if diff <= 15 and diff >= 0:
                    alerts.append({
                        "id": g["id"],
                        "tip": "info",
                        "baslik": "👶 Yaklaşan Doğum!",
                        "mesaj": f"{g['hayvan_adi'] or 'İnek'} ({g['hayvan_kupe']}) için tahmini doğuma {diff} gün kaldı!",
                        "kategori": "dogum",
                        "tarih": g["tahmini_dogum_tarihi"]
                    })
                elif diff < 0 and diff >= -10:
                    alerts.append({
                        "id": g["id"],
                        "tip": "danger",
                        "baslik": "🚨 Doğum Zamanı Geldi/Geçti",
                        "mesaj": f"{g['hayvan_adi'] or 'İnek'} ({g['hayvan_kupe']}) doğum tarihi {abs(diff)} gün önceydi. Kontrol edin!",
                        "kategori": "dogum",
                        "tarih": g["tahmini_dogum_tarihi"]
                    })
            except:
                pass

    conn.close()
    return alerts


# --- HAYVANLAR VE BUZAĞILAR ---
@app.get("/api/animals")
def list_animals(user: str = Query("cihan"), search: Optional[str] = None):
    conn = get_db()
    c = conn.cursor()

    query_yetiskin = "SELECT *, 'Yetişkin' as kategori FROM hayvanlar WHERE LOWER(kullanici_adi)=LOWER(?) AND durum='Aktif'"
    params_yetiskin = [user]

    query_buzagi = "SELECT *, 'Buzağı' as kategori FROM buzagilar WHERE LOWER(kullanici_adi)=LOWER(?) AND durum='Aktif'"
    params_buzagi = [user]

    if search:
        s = f"%{search.strip()}%"
        query_yetiskin += " AND (kupe_no LIKE ? OR isim LIKE ? OR cins LIKE ?)"
        params_yetiskin.extend([s, s, s])
        query_buzagi += " AND (kupe_no LIKE ? OR isim LIKE ? OR cins LIKE ?)"
        params_buzagi.extend([s, s, s])

    c.execute(query_yetiskin, params_yetiskin)
    yetiskinler = [dict(r) for r in c.fetchall()]

    c.execute(query_buzagi, params_buzagi)
    buzagilar = [dict(r) for r in c.fetchall()]

    conn.close()
    return {
        "yetiskinler": yetiskinler,
        "buzagilar": buzagilar,
        "toplam": len(yetiskinler) + len(buzagilar)
    }

@app.get("/api/animals/{kupe_no}")
def get_animal_detail(kupe_no: str, user: str = Query("cihan")):
    conn = get_db()
    c = conn.cursor()

    # Önce yetişkinlerde ara
    c.execute("SELECT * FROM hayvanlar WHERE LOWER(kullanici_adi)=LOWER(?) AND kupe_no=?", (user, kupe_no))
    hayvan = c.fetchone()
    kategori = "Yetişkin"

    if not hayvan:
        c.execute("SELECT * FROM buzagilar WHERE LOWER(kullanici_adi)=LOWER(?) AND kupe_no=?", (user, kupe_no))
        hayvan = c.fetchone()
        kategori = "Buzağı"

    if not hayvan:
        conn.close()
        raise HTTPException(status_code=404, detail=f"{kupe_no} numaralı hayvan bulunamadı!")

    hayvan_dict = dict(hayvan)
    hayvan_dict["kategori"] = kategori

    # Aşıları
    c.execute("SELECT * FROM asi_takip WHERE LOWER(kullanici_adi)=LOWER(?) AND hayvan_kupe=? ORDER BY planlanan_tarih DESC", (user, kupe_no))
    hayvan_dict["asilar"] = [dict(r) for r in c.fetchall()]

    # Son 14 gün süt verimleri (varsa)
    c.execute("SELECT * FROM sut_kayitlari WHERE LOWER(kullanici_adi)=LOWER(?) AND hayvan_kupe=? ORDER BY tarih DESC LIMIT 14", (user, kupe_no))
    hayvan_dict["sut_kayitlari"] = [dict(r) for r in c.fetchall()]

    # Gebelik geçmişi
    c.execute("SELECT * FROM gebelik_takip WHERE LOWER(kullanici_adi)=LOWER(?) AND hayvan_kupe=? ORDER BY tohumlama_tarihi DESC", (user, kupe_no))
    hayvan_dict["gebelikler"] = [dict(r) for r in c.fetchall()]

    conn.close()
    return hayvan_dict

@app.post("/api/animals")
def create_animal(data: AnimalCreate):
    conn = get_db()
    c = conn.cursor()
    # Aynı küpe no var mı?
    c.execute("SELECT id FROM hayvanlar WHERE LOWER(kullanici_adi)=LOWER(?) AND kupe_no=?", (data.kullanici_adi, data.kupe_no))
    if c.fetchone():
        conn.close()
        raise HTTPException(status_code=400, detail=f"{data.kupe_no} küpeli hayvan zaten kayıtlı!")

    c.execute("""
        INSERT INTO hayvanlar (kupe_no, isim, tur, cins, cinsiyet, dogum_tarihi, kullanici_adi, olusturma_tarihi)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (data.kupe_no, data.isim or f"İnek {data.kupe_no}", data.tur, data.cins, data.cinsiyet, data.dogum_tarihi, data.kullanici_adi, datetime.now().strftime("%Y-%m-%d")))
    conn.commit()
    conn.close()
    return {"status": "success", "message": f"{data.kupe_no} küpeli hayvan eklendi!"}

@app.post("/api/calves")
def create_calf(data: CalfCreate):
    conn = get_db()
    c = conn.cursor()
    c.execute("""
        INSERT INTO buzagilar (kupe_no, isim, dogum_tarihi, cinsiyet, cins, anne_adi, anne_kupe_no, baba_kupe_no, dogum_agirligi, kullanici_adi, olusturma_tarihi)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (data.kupe_no, data.isim or f"Buzağı {data.kupe_no}", data.dogum_tarihi, data.cinsiyet, data.cins,
          data.anne_adi, data.anne_kupe_no, data.baba_kupe_no, data.dogum_agirligi, data.kullanici_adi, datetime.now().strftime("%Y-%m-%d")))
    conn.commit()
    conn.close()
    return {"status": "success", "message": f"{data.kupe_no} buzağısı sisteme kaydedildi!"}

@app.delete("/api/animals/{kategori}/{id}")
def delete_animal(kategori: str, id: int, user: str = Query("cihan")):
    conn = get_db()
    c = conn.cursor()
    tbl = "hayvanlar" if kategori.lower() == "yetiskin" else "buzagilar"
    c.execute(f"UPDATE {tbl} SET durum='Arşivlendi' WHERE id=? AND LOWER(kullanici_adi)=LOWER(?)", (id, user))
    conn.commit()
    conn.close()
    return {"status": "success", "message": "Kayıt arşivlendi/silindi."}


# --- SÜT TAKİBİ ENDPOINTS ---
@app.get("/api/milk")
def get_milk_history(user: str = Query("cihan"), gun_sayisi: int = 14):
    conn = get_db()
    c = conn.cursor()
    
    # Tarih bazında toplamlar
    c.execute("""
        SELECT tarih, 
               SUM(CASE WHEN sagim_vakti='Sabah' THEN litre ELSE 0 END) as sabah_litre,
               SUM(CASE WHEN sagim_vakti='Akşam' THEN litre ELSE 0 END) as aksam_litre,
               SUM(litre) as toplam_litre,
               COUNT(DISTINCT hayvan_kupe) as sagilan_hayvan_sayisi
        FROM sut_kayitlari
        WHERE LOWER(kullanici_adi)=LOWER(?)
        GROUP BY tarih
        ORDER BY tarih DESC
        LIMIT ?
    """, (user, gun_sayisi))
    gunluk_veriler = [dict(r) for r in c.fetchall()]

    # Son 30 kaydı detaylı çek
    c.execute("""
        SELECT * FROM sut_kayitlari 
        WHERE LOWER(kullanici_adi)=LOWER(?) 
        ORDER BY tarih DESC, id DESC 
        LIMIT 30
    """, (user,))
    detaylar = [dict(r) for r in c.fetchall()]

    conn.close()
    return {
        "gunluk_ozet": list(reversed(gunluk_veriler)), # Kronolojik sıralama
        "son_kayitlar": detaylar
    }

@app.post("/api/milk")
def add_milk_record(data: MilkCreate):
    conn = get_db()
    c = conn.cursor()
    c.execute("""
        INSERT INTO sut_kayitlari (hayvan_kupe, tarih, sagim_vakti, litre, yag_orani, notlar, kullanici_adi, olusturma_tarihi)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (data.hayvan_kupe or "Genel Sürü", data.tarih, data.sagim_vakti, data.litre, data.yag_orani, data.notlar, data.kullanici_adi, datetime.now().strftime("%Y-%m-%d")))
    conn.commit()
    conn.close()
    return {"status": "success", "message": f"{data.litre} litre süt kaydı eklendi!"}


# --- GEBELİK VE TOHUMLAMA ---
@app.get("/api/pregnancy")
def get_pregnancy_list(user: str = Query("cihan")):
    conn = get_db()
    c = conn.cursor()
    c.execute("""
        SELECT * FROM gebelik_takip 
        WHERE LOWER(kullanici_adi)=LOWER(?) 
        ORDER BY tohumlama_tarihi DESC
    """, (user,))
    kayitlar = []
    today = datetime.now().date()
    for r in c.fetchall():
        d = dict(r)
        # Gebelik günü ve kalan gün hesapla
        try:
            t_date = datetime.strptime(d["tohumlama_tarihi"], "%Y-%m-%d").date()
            gebelik_gunu = (today - t_date).days
            d["gebelik_gunu"] = max(0, gebelik_gunu)
            
            if d["tahmini_dogum_tarihi"]:
                dogum_date = datetime.strptime(d["tahmini_dogum_tarihi"], "%Y-%m-%d").date()
                d["kalan_gun"] = (dogum_date - today).days
                # Gebelik ilerleme yüzdesi (283 gün üzerinden)
                d["ilerleme_yuzdesi"] = min(100, max(0, int((gebelik_gunu / 283) * 100)))
            else:
                d["kalan_gun"] = None
                d["ilerleme_yuzdesi"] = 0
        except Exception:
            d["gebelik_gunu"] = 0
            d["kalan_gun"] = None
            d["ilerleme_yuzdesi"] = 0
        kayitlar.append(d)

    conn.close()
    return kayitlar

@app.post("/api/pregnancy")
def add_pregnancy(data: PregnancyCreate):
    conn = get_db()
    c = conn.cursor()
    
    # Otomatik tarihler hesaplama
    t_date = datetime.strptime(data.tohumlama_tarihi, "%Y-%m-%d")
    kontrol_tarihi = (t_date + timedelta(days=50)).strftime("%Y-%m-%d")
    kuru_tarihi = (t_date + timedelta(days=220)).strftime("%Y-%m-%d")
    dogum_tarihi = (t_date + timedelta(days=283)).strftime("%Y-%m-%d")

    # Hayvan adını çek (yoksa)
    hayvan_adi = data.hayvan_adi
    if not hayvan_adi:
        c.execute("SELECT isim FROM hayvanlar WHERE kupe_no=? AND LOWER(kullanici_adi)=LOWER(?)", (data.hayvan_kupe, data.kullanici_adi))
        row = c.fetchone()
        if row and row["isim"]:
            hayvan_adi = row["isim"]

    c.execute("""
        INSERT INTO gebelik_takip (hayvan_kupe, hayvan_adi, tohumlama_tarihi, tohumlama_turu, baba_irki, gebelik_kontrol_tarihi, kuruya_alma_tarihi, tahmini_dogum_tarihi, durum, notlar, kullanici_adi, olusturma_tarihi)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'Tohumlandı', ?, ?, ?)
    """, (data.hayvan_kupe, hayvan_adi, data.tohumlama_tarihi, data.tohumlama_turu, data.baba_irki, kontrol_tarihi, kuru_tarihi, dogum_tarihi, data.notlar, data.kullanici_adi, datetime.now().strftime("%Y-%m-%d")))
    conn.commit()
    conn.close()
    return {"status": "success", "message": f"{data.hayvan_kupe} için tohumlama kaydı açıldı! Tahmini Doğum: {dogum_tarihi}"}

@app.patch("/api/pregnancy/{id}/status")
def update_pregnancy_status(id: int, durum: str = Query(...), user: str = Query("cihan")):
    conn = get_db()
    c = conn.cursor()
    c.execute("UPDATE gebelik_takip SET durum=? WHERE id=? AND LOWER(kullanici_adi)=LOWER(?)", (durum, id, user))
    conn.commit()
    conn.close()
    return {"status": "success", "message": f"Durum '{durum}' olarak güncellendi."}


# --- AŞI VE SAĞLIK ---
@app.get("/api/vaccines")
def get_vaccines(user: str = Query("cihan")):
    conn = get_db()
    c = conn.cursor()
    c.execute("""
        SELECT * FROM asi_takip 
        WHERE LOWER(kullanici_adi)=LOWER(?) 
        ORDER BY CASE WHEN durum='Yapılmadı' THEN 0 ELSE 1 END, planlanan_tarih ASC
    """, (user,))
    asilar = [dict(r) for r in c.fetchall()]
    conn.close()
    return asilar

@app.post("/api/vaccines")
def add_vaccine(data: VaccineCreate):
    conn = get_db()
    c = conn.cursor()
    c.execute("""
        INSERT INTO asi_takip (hayvan_kupe, hayvan_adi, asi_adi, planlanan_tarih, durum, notlar, kullanici_adi, olusturma_tarihi)
        VALUES (?, ?, ?, ?, 'Yapılmadı', ?, ?, ?)
    """, (data.hayvan_kupe, data.hayvan_adi, data.asi_adi, data.planlanan_tarih, data.notlar, data.kullanici_adi, datetime.now().strftime("%Y-%m-%d")))
    conn.commit()
    conn.close()
    return {"status": "success", "message": "Aşı başarıyla planlandı!"}

@app.patch("/api/vaccines/{id}/complete")
def complete_vaccine(id: int, user: str = Query("cihan")):
    conn = get_db()
    c = conn.cursor()
    now_str = datetime.now().strftime("%Y-%m-%d")
    c.execute("UPDATE asi_takip SET durum='Yapıldı', yapilis_tarihi=? WHERE id=? AND LOWER(kullanici_adi)=LOWER(?)", (now_str, id, user))
    conn.commit()
    conn.close()
    return {"status": "success", "message": "Aşı 'Yapıldı' olarak kaydedildi!"}


# --- KASA & FİNANS ---
@app.get("/api/finance")
def get_finance(user: str = Query("cihan")):
    conn = get_db()
    c = conn.cursor()
    
    # Son 30 gider
    c.execute("SELECT *, 'Gider' as tip FROM giderler WHERE LOWER(kullanici_adi)=LOWER(?) ORDER BY tarih DESC LIMIT 30", (user,))
    giderler = [dict(r) for r in c.fetchall()]

    # Son 30 gelir
    c.execute("SELECT *, 'Gelir' as tip FROM gelirler WHERE LOWER(kullanici_adi)=LOWER(?) ORDER BY tarih DESC LIMIT 30", (user,))
    gelirler = [dict(r) for r in c.fetchall()]

    # Aylık özet (son 6 ay)
    c.execute("""
        SELECT strftime('%Y-%m', tarih) as ay, SUM(tutar) as toplam_gider 
        FROM giderler WHERE LOWER(kullanici_adi)=LOWER(?) GROUP BY ay ORDER BY ay DESC LIMIT 6
    """, (user,))
    aylik_gider = {r["ay"]: r["toplam_gider"] for r in c.fetchall()}

    c.execute("""
        SELECT strftime('%Y-%m', tarih) as ay, SUM(tutar) as toplam_gelir 
        FROM gelirler WHERE LOWER(kullanici_adi)=LOWER(?) GROUP BY ay ORDER BY ay DESC LIMIT 6
    """, (user,))
    aylik_gelir = {r["ay"]: r["toplam_gelir"] for r in c.fetchall()}

    aylar = sorted(list(set(list(aylik_gider.keys()) + list(aylik_gelir.keys()))))
    aylik_grafik = []
    for a in aylar:
        g = aylik_gelir.get(a, 0.0)
        e = aylik_gider.get(a, 0.0)
        aylik_grafik.append({
            "ay": a,
            "gelir": g,
            "gider": e,
            "kar": g - e
        })

    conn.close()
    return {
        "giderler": giderler,
        "gelirler": gelirler,
        "aylik_grafik": aylik_grafik
    }

@app.post("/api/expenses")
def add_expense(data: ExpenseCreate):
    conn = get_db()
    c = conn.cursor()
    c.execute("""
        INSERT INTO giderler (gider_turu, miktar, birim, tutar, tarih, aciklama, kullanici_adi, olusturma_tarihi)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (data.gider_turu, data.miktar, data.birim, data.tutar, data.tarih, data.aciklama, data.kullanici_adi, datetime.now().strftime("%Y-%m-%d")))
    conn.commit()
    conn.close()
    return {"status": "success", "message": f"{data.tutar:,.2f} TL tutarındaki gider kaydedildi."}

@app.post("/api/incomes")
def add_income(data: IncomeCreate):
    conn = get_db()
    c = conn.cursor()
    c.execute("""
        INSERT INTO gelirler (gelir_turu, miktar, birim, tutar, tarih, alici, aciklama, kullanici_adi, olusturma_tarihi)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (data.gelir_turu, data.miktar, data.birim, data.tutar, data.tarih, data.alici, data.aciklama, data.kullanici_adi, datetime.now().strftime("%Y-%m-%d")))
    conn.commit()
    conn.close()
    return {"status": "success", "message": f"{data.tutar:,.2f} TL tutarındaki gelir kasaya işlendi!"}

@app.delete("/api/finance/{tip}/{id}")
def delete_finance_item(tip: str, id: int, user: str = Query("cihan")):
    conn = get_db()
    c = conn.cursor()
    tbl = "giderler" if tip.lower() == "gider" else "gelirler"
    c.execute(f"DELETE FROM {tbl} WHERE id=? AND LOWER(kullanici_adi)=LOWER(?)", (id, user))
    conn.commit()
    conn.close()
    return {"status": "success", "message": "Kayıt silindi."}


# --- ANA SAYFA (INDEX.HTML / PWA) ---
@app.get("/", response_class=HTMLResponse)
def serve_index():
    index_file = os.path.join(STATIC_DIR, "index.html")
    if os.path.exists(index_file):
        with open(index_file, "r", encoding="utf-8") as f:
            return f.read()
    return "<h1>Çiftlik 360 Yükleniyor...</h1>"

@app.get("/manifest.json")
def get_manifest():
    return FileResponse(os.path.join(STATIC_DIR, "manifest.json"), media_type="application/manifest+json")

@app.get("/indir")
@app.get("/apk")
def download_apk():
    apk_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'Ciftlik360.apk')
    if os.path.exists(apk_path):
        return FileResponse(apk_path, filename="Ciftlik360.apk", media_type="application/vnd.android.package-archive")
    raise HTTPException(status_code=404, detail="APK dosyası bulunamadı")

@app.get("/sw.js")
def get_sw():
    return FileResponse(os.path.join(STATIC_DIR, "sw.js"), media_type="application/javascript")


if __name__ == "__main__":
    import uvicorn
    init_db()

    # Bilgisayarın yerel ağ IP adresini bul
    def get_local_ip():
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except Exception:
            return "127.0.0.1"

    local_ip = get_local_ip()
    port = 8000

    print("=" * 65)
    print("CIFTLIK 360 - MOBIL CIFTLIK YONETIM UYGULAMASI HAZIR!")
    print("=" * 65)
    print(f"Bilgisayardan Giris : http://localhost:{port}")
    print(f"Telefondan Giris    : http://{local_ip}:{port}")
    print("=" * 65)
    print("Telefonunuz ayni Wi-Fi agina bagliyken yukaridaki adresi")
    print("telefonunuzun tarayicisina yazarak hemen uygulamayi acabilirsiniz!")
    print("=" * 65)

    uvicorn.run("server:app", host="0.0.0.0", port=port, reload=True)
