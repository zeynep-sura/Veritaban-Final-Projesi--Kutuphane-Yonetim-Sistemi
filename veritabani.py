import mysql.connector
import hashlib


class Veritabani:
    def __init__(self):
        self.config = {
            'user': 'kutuphane_app',
            'password': '1234',
            'host': 'localhost',
            'database': 'kutuphaneOtomasyonu',
            'auth_plugin': 'mysql_native_password',
            'raise_on_warnings': True
        }
        
        self.conn = None
        self.cursor = None
        
        self.baglan()

    def baglan(self):
        try:
            self.conn = mysql.connector.connect(**self.config)
            self.cursor = self.conn.cursor() 
            print("Veritabanı bağlantısı başarılı.")
        except mysql.connector.Error as err:
            print(f"BAĞLANTI HATASI: {err}")
            self.conn = None
            self.cursor = None

    def kullanici_dogrula(self, kadi, sifre_duz):
        if self.conn is None or not self.conn.is_connected():
            self.baglan()
            
        if self.conn is None: return None
            
        try:
            cursor = self.conn.cursor(dictionary=True)
            sifreli_hal = hashlib.sha256(sifre_duz.encode('utf-8')).hexdigest()
            sql = "SELECT * FROM KULLANICI WHERE KullaniciAdi = %s AND Sifre = %s"
            cursor.execute(sql, (kadi, sifreli_hal))
            user_data = cursor.fetchone()
            cursor.close()

            if user_data:
                gorunen_isim = user_data.get('AdSoyad')
                if not gorunen_isim:
                    gorunen_isim = user_data.get('KullaniciAdi')
                return {
                    'AdSoyad': gorunen_isim,         
                    'Rol': user_data.get('Rol', 'Personel') 
                }
            return None
            
        except Exception as e:
            print(f"Giriş Hatası: {e}")
            return None
        
# ÜYE İŞLEMLERİ
    
    def uye_ekle(self, ad, soyad, email, telefon):
        if self.cursor is None: return False
        query = "INSERT INTO UYE (Ad, Soyad, Email, Telefon) VALUES (%s, %s, %s, %s)"
        try:
            self.cursor.execute(query, (ad, soyad, email, telefon))
            self.conn.commit()
            return True
        except Exception as e:
            print(f"Üye Ekleme Hatası: {e}")
            return False

    def uye_listele(self):
        if self.conn is None or not self.conn.is_connected(): self.baglan()
        if self.cursor is None: return []

        query = "SELECT ID, Ad, Soyad, Email, Telefon, ToplamBorc FROM UYE ORDER BY Ad ASC"
        try:
            self.cursor.execute(query)
            return self.cursor.fetchall()
        except Exception as e:
            print(f"Listeleme Hatası: {e}")
            return []

    def uye_ara1(self, kelime):
        if self.conn is None or not self.conn.is_connected():
            self.baglan()
        if self.cursor is None: return []

        try:
            query = """
                SELECT ID, Ad, Soyad, Email, Telefon,ToplamBorc
                FROM UYE 
                WHERE LOWER(CONCAT(IFNULL(Ad,''), ' ', IFNULL(Soyad,''))) LIKE LOWER(%s) 
                   OR LOWER(IFNULL(Email,'')) LIKE LOWER(%s)
            """
            val = f"%{kelime}%"
            self.cursor.execute(query, (val, val))
            return self.cursor.fetchall()

        except Exception as e:
            print(f"HATA: {e}")
            return []
    def uye_guncelle(self, uid, ad, soyad, email, tel):
        if self.cursor is None: return False
        try:
            q = "UPDATE UYE SET Ad=%s, Soyad=%s, Email=%s, Telefon=%s WHERE ID=%s"
            self.cursor.execute(q, (ad, soyad, email, tel, uid))
            self.conn.commit()
            return True
        except:
            return False

    def uye_sil(self, uid):   #trigger
        if self.cursor is None: return False, "Bağlantı yok"
        
        try:
            self.cursor.execute("DELETE FROM UYE WHERE ID=%s", (uid,))
            self.conn.commit()
            return True, "Üye başarıyla silindi."
        
        except mysql.connector.Error as e:
            hata_mesaji = str(e.msg)
            print(f"Silme Engellendi (Trigger): {hata_mesaji}")
            
            if "Foreign key constraint" in hata_mesaji:
                return False, "Bu üye silinemez! Geçmiş işlem kayıtları mevcut."
            else:
                return False, f"Silinemez: {hata_mesaji}"
            
    # RAPORLAMA 
    def uye_ozet_bilgi_getir(self, uye_id):
        if self.cursor is None: return None
        try:
            # Prosedürü çağır
            self.cursor.callproc('sp_UyeOzetRapor', (uye_id,))
            
            ozet = None
            for result in self.cursor.stored_results():
                ozet = result.fetchone() 
                
            return ozet 
            
        except Exception as e:
            print(f"Özet Rapor Hatası: {e}")
            return None        

    #KİTAP VE KATEGORİ İŞLEMLERİ
    
    def kategorileri_getir(self):
        if self.cursor is None: return []
        try:
            self.cursor.execute("SELECT * FROM KATEGORI ORDER BY Ad ASC")
            return self.cursor.fetchall()
        except:
            return []
        
    def kategori_ekle(self, ad):
        if self.cursor is None: return False
        try:
            ad = ad.strip().title()
            self.cursor.execute("SELECT ID FROM KATEGORI WHERE LOWER(Ad) = LOWER(%s)", (ad,))
            if self.cursor.fetchone():
                print("Bu kategori zaten var.")
                return False 

            self.cursor.execute("INSERT INTO KATEGORI (Ad) VALUES (%s)", (ad,))
            self.conn.commit()
            return True
        except Exception as e:
            print(f"Kategori Hatası: {e}")
            return False

    def kategori_sil(self, kat_id):
        if self.cursor is None: return False, "Veritabanı bağlantısı yok"
        try:
            self.cursor.execute("DELETE FROM KATEGORI WHERE ID=%s", (kat_id,))
            self.conn.commit()
            return True, "Kategori silindi."
        except mysql.connector.Error as e:
            if e.errno == 1451:
                return False, "Bu kategori silinemez! İçinde kayıtlı kitaplar var."
            return False, f"Hata: {e}"
    def kategori_guncelle(self, kat_id, yeni_ad):
        if self.cursor is None: return False, "Bağlantı yok"
        try:
            yeni_ad = yeni_ad.strip().title()
            check_q = "SELECT ID FROM KATEGORI WHERE LOWER(Ad) = LOWER(%s) AND ID != %s"
            self.cursor.execute(check_q, (yeni_ad, kat_id))
            if self.cursor.fetchone():
                return False, "Bu isimde başka bir kategori zaten var."
            
            update_q = "UPDATE KATEGORI SET Ad=%s WHERE ID=%s"
            self.cursor.execute(update_q, (yeni_ad, kat_id))
            self.conn.commit()
            return True, "Kategori ismi güncellendi."
            
        except Exception as e:
            return False, f"Hata: {e}"

    def kitap_ekle(self, ad, yazar, yayinevi, yil, kategori_id, adet):
        if self.cursor is None: return False
        
        try:
            ad = ad.strip().title()
            yazar = yazar.strip().title()
            yayinevi = yayinevi.strip().title()
            adet = int(adet)
            
            check_query = """
                SELECT ID, ToplamAdet
                FROM KITAP 
                WHERE LOWER(KitapAdi) = LOWER(%s) AND LOWER(Yazar) = LOWER(%s) AND LOWER(Yayinevi) = LOWER(%s)
            """
            self.cursor.execute(check_query, (ad, yazar, yayinevi))
            kayit = self.cursor.fetchone()
            
            p_id = 0
            guncel_stok = adet

            if kayit:
                p_id = kayit[0]
                guncel_stok = kayit[1] + adet
            else:
                p_id = 0
                guncel_stok = adet

            
            args = (p_id, ad, yazar, yayinevi, yil, kategori_id, guncel_stok)
            
            self.cursor.callproc('sp_KitapEkleVeyaGuncelle', args)
            self.conn.commit()
            
            for result in self.cursor.stored_results(): 
                pass

            return True
            
        except Exception as e:
            print(f"Kitap Ekleme (SP) Hatası: {e}")
            return False
        
    def kitap_sil(self, kid):
        if self.cursor is None: return False
        try:
            self.cursor.execute("DELETE FROM ODUNC WHERE KitapID = %s", (kid,))
            self.cursor.execute("DELETE FROM KITAP WHERE ID=%s", (kid,))
            self.conn.commit()
            return True
        except:
            return False
        
    def kitap_guncelle(self, kid, ad, yazar, yayinevi, yil, kategori_id, stok):
        if self.cursor is None: return False
        try:
            query = """
                UPDATE KITAP 
                SET KitapAdi=%s, Yazar=%s, Yayinevi=%s, BasimYili=%s, KategoriID=%s, ToplamAdet=%s 
                WHERE ID=%s
            """
            self.cursor.execute(query, (ad, yazar, yayinevi, yil, kategori_id, stok, kid))
            self.conn.commit()
            return True
        except Exception as e:
            print(f"Güncelleme Hatası: {e}")
            return False

    #prosedür
    def odunc_ver(self, Uye_Id, Kitap_Id, Personel_Id):
        if self.cursor is None: return False, "Veritabanı bağlantısı yok"

        try:
            kontrol_sorgusu = """
                SELECT ID FROM ODUNC 
                WHERE UyeID = %s AND KitapID = %s AND TeslimTarihi IS NULL
            """
            self.cursor.execute(kontrol_sorgusu, (Uye_Id, Kitap_Id))
            zaten_var = self.cursor.fetchone()

            if zaten_var:
                return False, "HATA: Bu üye bu kitabı zaten ödünç almış! Teslim etmeden tekrar alamaz."

            args = (Uye_Id, Kitap_Id, Personel_Id)
            self.cursor.callproc('sp_YeniOduncVer', args)
            self.conn.commit()
            
            for result in self.cursor.stored_results():
                pass 

            return True, "Kitap başarıyla ödünç verildi."
            
        except mysql.connector.Error as err:
            return False, f"İşlem Başarısız: {err.msg}"
        except Exception as e:
            return False, f"Genel Hata: {e}"
    
    def uyenin_aktif_oduncleri(self, uye_id):
        if self.cursor is None: return []
        try:
            self.conn.commit()
            query = """
            SELECT 
                O.ID, 
                K.KitapAdi, 
                U.Ad, 
                U.Soyad, 
                O.OduncTarihi, 
                O.SonTeslimTarihi
            FROM ODUNC as O
            INNER JOIN KITAP as K ON O.KitapID = K.ID
            INNER JOIN UYE as U ON O.UyeID = U.ID
            WHERE O.UyeID = %s AND O.TeslimTarihi IS NULL
            ORDER BY O.OduncTarihi DESC
        """
            self.cursor.execute(query, (uye_id,))
            return self.cursor.fetchall()
        except Exception as e:
            print(f"Aktif Ödünç Hatası: {e}")
            return []

    def uyeleri_getir(self):
        if self.cursor is None: return []
        try:
            self.cursor.execute("SELECT * FROM UYE")
            return self.cursor.fetchall()
        except Exception as e:
            print(f"Üye Getir Hatası: {e}")
            return []

    def uye_ara(self, arama_kelimesi):
        if self.cursor is None: return []
        try:
            query = "SELECT * FROM UYE WHERE Ad LIKE %s OR Soyad LIKE %s"
            val = (f"%{arama_kelimesi}%", f"%{arama_kelimesi}%")
            self.cursor.execute(query, val)
            return self.cursor.fetchall()
        except Exception as e:
            print(f"Üye Ara Hatası: {e}")
            return []

    def kitaplari_getir(self):
        if self.cursor is None: return []
        try:
            query = """
                SELECT 
                    K.ID, 
                    K.KitapAdi, 
                    K.Yazar, 
                    TG.Ad, 
                    K.Yayinevi, 
                    K.BasimYili, 
                    K.ToplamAdet, 
                    K.MevcutAdet
                FROM KITAP K
                LEFT JOIN KATEGORI TG ON K.KategoriID = TG.ID
                ORDER BY K.ID ASC
            """
            self.cursor.execute(query)
            return self.cursor.fetchall()
        except Exception as e:
            print(f"Hata: {e}")
            return []

    def kitap_ara(self, arama_metni, kriter="KitapAdi"):
    
        if self.cursor is None: 
            print("Cursor yok!")
            return []
        
        try:
            
            args = (kriter, arama_metni)
            self.cursor.callproc('sp_KitapAra', args)
            
            sonuclar = []
            for result in self.cursor.stored_results():
                rows = result.fetchall()
                if rows:
                    sonuclar.extend(rows)
                
            return sonuclar

        except Exception as e:
            print(f"Kitap Ara Hatası: {e}")
            return []
        
    def tum_aktif_oduncleri_getir(self):
        if self.cursor is None: return []
        try:
            query = """
                SELECT 
                    O.ID, 
                    K.KitapAdi, 
                    U.Ad, 
                    U.Soyad, 
                    O.OduncTarihi, 
                    O.SonTeslimTarihi
                FROM ODUNC O
                INNER JOIN KITAP K ON O.KitapID = K.ID
                INNER JOIN UYE U ON O.UyeID = U.ID
                WHERE O.TeslimTarihi IS NULL
                ORDER BY O.SonTeslimTarihi ASC
            """
            self.cursor.execute(query)
            return self.cursor.fetchall()
        except Exception as e:
            print(f"Tüm Aktif Ödünçleri Getirme Hatası: {e}")
            return []
    
    
    def aktif_oduncleri_getir(self, arama=""):
        if self.cursor is None: return []
        try:
            self.conn.commit()
            query = """
                SELECT 
                    O.ID, 
                    U.Ad,
                    U.Soyad, 
                    K.KitapAdi, 
                    O.OduncTarihi, 
                    O.SonTeslimTarihi
                FROM ODUNC O
                JOIN UYE U ON O.UyeID = U.ID
                JOIN KITAP K ON O.KitapID = K.ID
                WHERE O.TeslimTarihi IS NULL
                AND (
                    U.Ad LIKE %s OR 
                    U.Soyad LIKE %s OR 
                    K.KitapAdi LIKE %s OR
                    DATE_FORMAT(O.OduncTarihi, '%d.%m.%Y') LIKE %s OR   -- Tarihe göre arama (Veriliş)
                    DATE_FORMAT(O.SonTeslimTarihi, '%d.%m.%Y') LIKE %s  -- Tarihe göre arama (Son Teslim)
                )
            """
            val = f"%{arama}%"
            
            # Sorguda toplam 5 tane soru işareti (%s) olduğu için val'i 5 kere gönderiyoruz
            self.cursor.execute(query, (val, val, val, val, val))
            
            return self.cursor.fetchall()
        except Exception as e:
            print(f"Listeleme Hatası: {e}")
            return []

    def kitap_teslim_al_prosedur(self, OduncId, TeslimTrihi):
        if self.conn is None or not self.conn.is_connected():
            self.baglan()
            
        try:
            # sp_KitapTeslimAl çağrılır.
            self.cursor.callproc('sp_KitapTeslimAl', (OduncId, TeslimTrihi))
            self.conn.commit() 
            
            ceza_sorgusu = "SELECT Tutar FROM CEZA WHERE OduncID = %s"
            self.cursor.execute(ceza_sorgusu, (OduncId,))
            ceza_verisi = self.cursor.fetchone()

            if ceza_verisi:
                # Eğer kayıt varsa ceza miktarını alıyoruz
                tutar = ceza_verisi[0]
                mesaj = f"Dikkat! Kitap gecikmiş. {tutar} TL ceza yansıtıldı."
                ceza_var_mi = True
            else:
                # Eğer kayıt yoksa kitap zamanında gelmiştir
                mesaj = "Kitap zamanında teslim alındı."
                ceza_var_mi = False
                
            return True, mesaj, ceza_var_mi

            

        except Exception as e:
            print(f"PROSEDÜR HATASI: {e}")
            return False, str(e), False
   
    # CEZA VE FİLTRELEME İŞLEMLERİ

    def ceza_icin_uyeleri_getir(self):
        if self.cursor is None: return []
        try:
            self.cursor.execute("SELECT ID, Ad, Soyad FROM UYE ORDER BY Ad ASC")
            return self.cursor.fetchall()
        except Exception as e:
            print(f"Üye Getirme Hatası: {e}")
            return []

    def cezalar_filtreli(self, uye_id, baslangic_tarihi, bitis_tarihi):
        if self.cursor is None: return []
        try:
            query = """
                SELECT 
                    C.ID, 
                    CONCAT(U.Ad, ' ', U.Soyad) as UyeTamAd,
                    K.KitapAdi,
                    C.Tutar,
                    C.OlusturmaTarihi,
                    C.Aciklama
                FROM CEZA C
                LEFT JOIN UYE U ON C.UyeID = U.ID
                LEFT JOIN ODUNC O ON C.OduncID = O.ID
                LEFT JOIN KITAP K ON O.KitapID = K.ID
                WHERE 1=1
            """
            params = []

            if uye_id != -1: 
                query += " AND C.UyeID = %s"
                params.append(uye_id)

            query += " AND DATE(C.OlusturmaTarihi) BETWEEN %s AND %s"
            params.append(baslangic_tarihi)
            params.append(bitis_tarihi)

            query += " ORDER BY C.OlusturmaTarihi DESC"

            self.cursor.execute(query, tuple(params))
            return self.cursor.fetchall()

        except Exception as e:
            print(f"Ceza Listeleme Hatası: {e}")
            return []
        
    

    # RAPORLAMA FONKSİYONLARI 

    def rapor_odunc_hareketleri(self, baslangic, bitis, uye_id=None):
        if self.cursor is None: return []
        
        sql = """
            SELECT 
                CONCAT(U.Ad, ' ', U.Soyad) as UyeAd,
                K.KitapAdi,
                O.OduncTarihi, 
                O.SonTeslimTarihi,
                O.TeslimTarihi,
                CASE 
                    WHEN O.TeslimTarihi IS NULL THEN 'Okuyor'
                    ELSE 'Teslim Etti'
                END as Durum
            FROM ODUNC O
            LEFT JOIN UYE U ON O.UyeID = U.ID
            LEFT JOIN KITAP K ON O.KitapID = K.ID
            WHERE (O.OduncTarihi BETWEEN %s AND %s)
        """
        params = [baslangic, bitis]

        if uye_id is not None and uye_id != -1:
            sql += " AND O.UyeID = %s"
            params.append(uye_id)
            
        sql += " ORDER BY O.OduncTarihi DESC"
        
        try:
            self.cursor.execute(sql, params)
            return self.cursor.fetchall()
        except mysql.connector.Error as e:
            print(f"Rapor Hatası 1: {e}")
            return []

    def rapor_gecikenler(self):
        if self.cursor is None: return []
        
        sql = """
            SELECT 
                CONCAT(U.Ad, ' ', U.Soyad) as UyeAd,
                K.KitapAdi,
                O.OduncTarihi,
                O.SonTeslimTarihi,
                DATEDIFF(CURDATE(), O.SonTeslimTarihi) as GecikmeGun
            FROM ODUNC O
            LEFT JOIN UYE U ON O.UyeID = U.ID
            LEFT JOIN KITAP K ON O.KitapID = K.ID
            WHERE O.TeslimTarihi IS NULL 
            AND O.SonTeslimTarihi < CURDATE()
            ORDER BY GecikmeGun DESC
        """
        try:
            self.cursor.execute(sql)
            return self.cursor.fetchall()
        except mysql.connector.Error as e:
            print(f"Rapor Hatası 2: {e}")
            return []
        
        
    def rapor_populer_kitaplar(self, limit=10):
        if self.cursor is None: return []
        
        sql = """
            SELECT 
                K.KitapAdi,
                K.Yazar,
                COUNT(O.ID) as OduncSayisi
            FROM ODUNC O
            LEFT JOIN KITAP K ON O.KitapID = K.ID
            GROUP BY K.ID, K.KitapAdi, K.Yazar
            ORDER BY OduncSayisi DESC
            LIMIT %s
        """
        try:
            self.cursor.execute(sql, (limit,))
            return self.cursor.fetchall()
        except mysql.connector.Error as e:
            print(f"Rapor Hatası 3: {e}")
            return []    
        
    def rapor_en_aktif_uyeler(self, limit=10):
        if self.cursor is None: return []
        
        sql = """
            SELECT 
                CONCAT(U.Ad, ' ', U.Soyad) as UyeAd,
                U.Telefon,
                COUNT(O.ID) as IslemSayisi
            FROM ODUNC O
            LEFT JOIN UYE U ON O.UyeID = U.ID
            GROUP BY U.ID, U.Ad, U.Soyad, U.Telefon
            ORDER BY IslemSayisi DESC
            LIMIT %s
        """
        try:
            self.cursor.execute(sql, (limit,))
            return self.cursor.fetchall()
        except Exception as e:
            print(f"Aktif Üye Rapor Hatası: {e}")
            return []

    def rapor_en_cok_ceza_alanlar(self, limit=10):
        if self.cursor is None: return []
        
        sql = """
            SELECT 
                CONCAT(U.Ad, ' ', U.Soyad) as UyeAd,
                COUNT(C.ID) as CezaSayisi,
                SUM(C.Tutar) as ToplamTutar
            FROM CEZA C
            LEFT JOIN UYE U ON C.UyeID = U.ID
            GROUP BY U.ID, U.Ad, U.Soyad
            ORDER BY ToplamTutar DESC
            LIMIT %s
        """
        try:
            self.cursor.execute(sql, (limit,))
            return self.cursor.fetchall()
        except Exception as e:
            print(f"Ceza Rapor Hatası: {e}")
            return []
     
    #           DİNAMİK SORGU 

    def dinamik_kitap_sorgula(self, filtreler):
        if self.cursor is None: return []

        sql = """
            SELECT 
                K.KitapAdi, 
                K.Yazar, 
                KAT.Ad, 
                K.BasimYili, 
                K.MevcutAdet
            FROM KITAP K
            LEFT JOIN KATEGORI KAT ON K.KategoriID = KAT.ID
            WHERE 1=1
        """
        params = []

        if filtreler.get('ad'):
            sql += " AND K.KitapAdi LIKE %s"
            params.append(f"%{filtreler['ad']}%") 

        if filtreler.get('yazar'):
            sql += " AND K.Yazar LIKE %s"
            params.append(f"%{filtreler['yazar']}%")

        if filtreler.get('kategori_id') and filtreler['kategori_id'] != -1:
            sql += " AND K.KategoriID = %s"
            params.append(filtreler['kategori_id'])

        if filtreler.get('yil_min'):
            sql += " AND K.BasimYili >= %s"
            params.append(filtreler['yil_min'])

        if filtreler.get('yil_max'):
            sql += " AND K.BasimYili <= %s"
            params.append(filtreler['yil_max'])

        if filtreler.get('sadece_mevcut'):
            sql += " AND K.MevcutAdet > 0"

        sirala_alan = filtreler.get('sirala_alan', 'KitapAdi')
        sirala_yon = filtreler.get('sirala_yon', 'ASC')
        
        izinli_alanlar = {
            'KITAPADI': 'K.KitapAdi', 
            'AD':       'K.KitapAdi',
            'YAZAR': 'K.Yazar', 
            'BASIMYILI': 'K.BasimYili'
        }
        db_alan = izinli_alanlar.get(sirala_alan, 'K.KitapAdi')
        sql += f" ORDER BY {db_alan} {sirala_yon}"

        try:
            self.cursor.execute(sql, params)
            return self.cursor.fetchall()
        except Exception as e:
            print(f"Dinamik Sorgu Hatası: {e}")
            return []
            
    def kategorileri_getir(self):
        if self.cursor is None: return []
        try:
            self.cursor.execute("SELECT ID, Ad FROM KATEGORI ORDER BY Ad")
            return self.cursor.fetchall()
        except Exception as e:
            print(f"Kategori Getirme Hatası: {e}")
            return []
       