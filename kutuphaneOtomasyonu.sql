-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Anamakine: localhost
-- Üretim Zamanı: 09 Oca 2026, 23:08:28
-- Sunucu sürümü: 10.4.28-MariaDB
-- PHP Sürümü: 8.2.4

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;


--==========================================================================
--ÖRNEK TEST VERİLERİ (Dosyanın en sonunda, hızlı test için eklenmiştir)
--==========================================================================
--
-- Veritabanı: `kutuphaneOtomasyonu`
--

DELIMITER $$
--
-- Yordamlar
--
CREATE DEFINER PROCEDURE `sp_KitapAra` (IN `p_kriter` VARCHAR(50), IN `p_aranan` VARCHAR(255))   BEGIN
    
    IF p_kriter = 'Genel' THEN
        SELECT * FROM KITAP 
        WHERE KitapAdi LIKE CONCAT('%', p_aranan, '%') 
           OR Yazar LIKE CONCAT('%', p_aranan, '%');
           
    ELSEIF p_kriter = 'KitapAdi' THEN
        SELECT * FROM KITAP WHERE KitapAdi LIKE CONCAT('%', p_aranan, '%');
        
    ELSEIF p_kriter = 'Yazar' THEN
        SELECT * FROM KITAP WHERE Yazar LIKE CONCAT('%', p_aranan, '%');

    END IF;
END$$

CREATE DEFINER PROCEDURE `sp_KitapEkleVeyaGuncelle` (IN `p_ID` INT, IN `p_Ad` VARCHAR(255), IN `p_Yazar` VARCHAR(255), IN `p_Yayinevi` VARCHAR(255), IN `p_Yil` INT, IN `p_KategoriID` INT, IN `p_Stok` INT)   BEGIN
    IF p_ID = 0 THEN
        -- Yeni Kayıt
        INSERT INTO KITAP (KitapAdi, Yazar, Yayinevi, BasimYili, KategoriID, MevcutAdet, ToplamAdet)
        VALUES (p_Ad, p_Yazar, p_Yayinevi, p_Yil, p_KategoriID, p_Stok, p_Stok);
    ELSE
        -- Güncelleme 
        UPDATE KITAP
        SET KitapAdi = p_Ad,
            Yazar = p_Yazar,
            Yayinevi = p_Yayinevi,
            BasimYili = p_Yil,       
            KategoriID = p_KategoriID, 
            
            MevcutAdet = MevcutAdet + (p_Stok - ToplamAdet),
            ToplamAdet = p_Stok
        WHERE ID = p_ID;
    END IF;
END$$

CREATE DEFINER PROCEDURE `sp_KitapTeslimAl` (IN `p_OduncID` INT, IN `p_TeslimTarihi` DATE)   BEGIN
    DECLARE v_SonTeslimTarihi DATE;
    DECLARE v_UyeID INT;
    DECLARE v_GecikmeGun INT;
    DECLARE v_CezaTutar DECIMAL(10,2);
    
    SELECT UyeID, SonTeslimTarihi INTO v_UyeID, v_SonTeslimTarihi FROM ODUNC WHERE ID = p_OduncID;
    
    START TRANSACTION;
        UPDATE ODUNC SET TeslimTarihi = p_TeslimTarihi WHERE ID = p_OduncID;
        
        IF p_TeslimTarihi > v_SonTeslimTarihi THEN
            SET v_GecikmeGun = DATEDIFF(p_TeslimTarihi, v_SonTeslimTarihi);
            SET v_CezaTutar = v_GecikmeGun * 10.00; 
            
            INSERT INTO CEZA (UyeID, OduncID, Tutar, Aciklama)
            VALUES (v_UyeID, p_OduncID, v_CezaTutar, CONCAT(v_GecikmeGun, ' gün gecikti.'));
        END IF;
    COMMIT;
END$$

CREATE DEFINER PROCEDURE `sp_UyeOzetRapor` (IN `p_UyeID` INT)   BEGIN
    SELECT 
        CONCAT(U.Ad, ' ', U.Soyad) as AdSoyad,
        
        IFNULL(U.ToplamBorc, 0) as ToplamBorc,
        
        (SELECT COUNT(*) FROM ODUNC WHERE UyeID = p_UyeID) as ToplamAlinanKitap,
        
        (SELECT COUNT(*) FROM ODUNC WHERE UyeID = p_UyeID AND TeslimTarihi IS NULL) as ElindekiKitapSayisi
        
    FROM UYE U
    WHERE U.ID = p_UyeID;
END$$

CREATE DEFINER PROCEDURE `sp_YeniOduncVer` (IN `p_UyeID` INT, IN `p_KitapID` INT, IN `p_PersonelID` INT)   BEGIN 
    DECLARE v_MevcutStok INT;
    DECLARE v_UyeKitapSayisi INT;
    
    SELECT MevcutAdet INTO v_MevcutStok FROM KITAP WHERE ID = p_KitapID;
    
    SELECT COUNT(*) INTO v_UyeKitapSayisi FROM ODUNC WHERE UyeID = p_UyeID AND TeslimTarihi IS NULL;
    
    IF v_MevcutStok IS NULL OR v_MevcutStok < 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hata: Bu kitap stokta yok.';
    ELSEIF v_UyeKitapSayisi >= 3 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hata: Üye kitap alma limiti dolu.';
    ELSE 
       
        INSERT INTO ODUNC(UyeID, KitapID, VerenKullaniciID, OduncTarihi, SonTeslimTarihi)
        VALUES(p_UyeID, p_KitapID, p_PersonelID, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 15 DAY));
    END IF;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Tablo için tablo yapısı `CEZA`
--

CREATE TABLE `CEZA` (
  `ID` int(11) NOT NULL,
  `UyeID` int(11) DEFAULT NULL,
  `OduncID` int(11) DEFAULT NULL,
  `Tutar` decimal(10,2) DEFAULT NULL,
  `OlusturmaTarihi` datetime DEFAULT current_timestamp(),
  `Aciklama` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


--
-- Tetikleyiciler `CEZA`
--
DELIMITER $$
CREATE TRIGGER `TR_CEZA_INSERT` AFTER INSERT ON `CEZA` FOR EACH ROW BEGIN
    UPDATE UYE SET ToplamBorc = IFNULL(ToplamBorc, 0) + NEW.Tutar WHERE ID = NEW.UyeID;

    INSERT INTO ISLEM_LOG (KullaniciAdi, IslemTuru, Aciklama, Tarih)
    VALUES (
        'Sistem', 
        'Ceza Kesildi', 
        CONCAT('Üye ID: ', NEW.UyeID, ' - Tutar: ', NEW.Tutar), 
        NOW()
    );
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Tablo için tablo yapısı `ISLEM_LOG`
--

CREATE TABLE `ISLEM_LOG` (
  `ID` int(11) NOT NULL,
  `KullaniciAdi` varchar(50) DEFAULT NULL,
  `IslemTuru` varchar(50) DEFAULT NULL,
  `Aciklama` text DEFAULT NULL,
  `Tarih` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;



--
-- Tablo için tablo yapısı `KATEGORI`
--

CREATE TABLE `KATEGORI` (
  `ID` int(11) NOT NULL,
  `Ad` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


--
-- Tablo için tablo yapısı `KITAP`
--

CREATE TABLE `KITAP` (
  `ID` int(11) NOT NULL,
  `KitapAdi` varchar(150) NOT NULL,
  `Yazar` varchar(100) DEFAULT NULL,
  `Yayinevi` varchar(100) DEFAULT NULL,
  `BasimYili` int(11) DEFAULT NULL,
  `KategoriID` int(11) DEFAULT NULL,
  `ToplamAdet` int(11) DEFAULT 1,
  `MevcutAdet` int(11) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


--
-- Tablo için tablo yapısı `KULLANICI`
--

CREATE TABLE `KULLANICI` (
  `ID` int(11) NOT NULL,
  `KullaniciAdi` varchar(50) NOT NULL,
  `Sifre` char(64) NOT NULL,
  `AdSoyad` varchar(100) DEFAULT NULL,
  `Rol` varchar(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;



--
-- Tablo için tablo yapısı `ODUNC`
--

CREATE TABLE `ODUNC` (
  `ID` int(11) NOT NULL,
  `UyeID` int(11) DEFAULT NULL,
  `KitapID` int(11) DEFAULT NULL,
  `VerenKullaniciID` int(11) DEFAULT NULL,
  `OduncTarihi` datetime DEFAULT current_timestamp(),
  `SonTeslimTarihi` datetime DEFAULT NULL,
  `TeslimTarihi` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;



--
-- Tetikleyiciler `ODUNC`
--
DELIMITER $$
CREATE TRIGGER `TR_ODUNC_INSERT` AFTER INSERT ON `ODUNC` FOR EACH ROW BEGIN
    UPDATE KITAP SET MevcutAdet = MevcutAdet - 1 WHERE ID = NEW.KitapID;

    INSERT INTO ISLEM_LOG (KullaniciAdi, IslemTuru, Aciklama, Tarih)
    VALUES (
        CAST(NEW.VerenKullaniciID AS CHAR), 
        'Ödünç Verme', 
        CONCAT('Kitap ID: ', NEW.KitapID, ' verildi. Üye ID: ', NEW.UyeID), 
        NOW()
    );
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `TR_ODUNC_UPDATE_TESLIM` AFTER UPDATE ON `ODUNC` FOR EACH ROW BEGIN
    IF OLD.TeslimTarihi IS NULL AND NEW.TeslimTarihi IS NOT NULL THEN
        
        UPDATE KITAP SET MevcutAdet = MevcutAdet + 1 WHERE ID = NEW.KitapID;

        INSERT INTO ISLEM_LOG (KullaniciAdi, IslemTuru, Aciklama, Tarih)
        VALUES (
            'Sistem', 
            'İade Alma', 
            CONCAT('Kitap ID: ', NEW.KitapID, ' iade alındı.'), 
            NOW()
        );
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Tablo için tablo yapısı `UYE`
--

CREATE TABLE `UYE` (
  `ID` int(11) NOT NULL,
  `Ad` varchar(50) NOT NULL,
  `Soyad` varchar(50) NOT NULL,
  `Email` varchar(100) DEFAULT NULL,
  `Telefon` varchar(20) DEFAULT NULL,
  `ToplamBorc` decimal(10,2) DEFAULT 0.00,
  `KayitTarihi` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;



--
-- Tetikleyiciler `UYE`
--
DELIMITER $$
CREATE TRIGGER `TR_UYE_DELETE_BLOCK` BEFORE DELETE ON `UYE` FOR EACH ROW BEGIN
    DECLARE v_Borc DECIMAL(10,2);
    DECLARE v_KitapSayisi INT;

    SELECT IFNULL(ToplamBorc, 0) INTO v_Borc FROM UYE WHERE ID = OLD.ID;
    
    SELECT COUNT(*) INTO v_KitapSayisi FROM ODUNC WHERE UyeID = OLD.ID AND TeslimTarihi IS NULL;

    IF v_Borc > 0 OR v_KitapSayisi > 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Hata: Bu üyenin borcu veya teslim etmediği kitabı var, silinemez!';
    END IF;
END
$$
DELIMITER ;

--
-- Dökümü yapılmış tablolar için indeksler
--

--
-- Tablo için indeksler `CEZA`
--
ALTER TABLE `CEZA`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `UyeID` (`UyeID`),
  ADD KEY `OduncID` (`OduncID`);

--
-- Tablo için indeksler `ISLEM_LOG`
--
ALTER TABLE `ISLEM_LOG`
  ADD PRIMARY KEY (`ID`);

--
-- Tablo için indeksler `KATEGORI`
--
ALTER TABLE `KATEGORI`
  ADD PRIMARY KEY (`ID`);

--
-- Tablo için indeksler `KITAP`
--
ALTER TABLE `KITAP`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `KategoriID` (`KategoriID`);

--
-- Tablo için indeksler `KULLANICI`
--
ALTER TABLE `KULLANICI`
  ADD PRIMARY KEY (`ID`),
  ADD UNIQUE KEY `KullaniciAdi` (`KullaniciAdi`);

--
-- Tablo için indeksler `ODUNC`
--
ALTER TABLE `ODUNC`
  ADD PRIMARY KEY (`ID`),
  ADD KEY `UyeID` (`UyeID`),
  ADD KEY `KitapID` (`KitapID`),
  ADD KEY `VerenKullaniciID` (`VerenKullaniciID`);

--
-- Tablo için indeksler `UYE`
--
ALTER TABLE `UYE`
  ADD PRIMARY KEY (`ID`);

--
-- Dökümü yapılmış tablolar için AUTO_INCREMENT değeri
--

--
-- Tablo için AUTO_INCREMENT değeri `CEZA`
--
ALTER TABLE `CEZA`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- Tablo için AUTO_INCREMENT değeri `ISLEM_LOG`
--
ALTER TABLE `ISLEM_LOG`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=80;

--
-- Tablo için AUTO_INCREMENT değeri `KATEGORI`
--
ALTER TABLE `KATEGORI`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- Tablo için AUTO_INCREMENT değeri `KITAP`
--
ALTER TABLE `KITAP`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- Tablo için AUTO_INCREMENT değeri `KULLANICI`
--
ALTER TABLE `KULLANICI`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- Tablo için AUTO_INCREMENT değeri `ODUNC`
--
ALTER TABLE `ODUNC`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=42;

--
-- Tablo için AUTO_INCREMENT değeri `UYE`
--
ALTER TABLE `UYE`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- Dökümü yapılmış tablolar için kısıtlamalar
--

--
-- Tablo kısıtlamaları `CEZA`
--
ALTER TABLE `CEZA`
  ADD CONSTRAINT `CEZA_ibfk_1` FOREIGN KEY (`UyeID`) REFERENCES `UYE` (`ID`),
  ADD CONSTRAINT `CEZA_ibfk_2` FOREIGN KEY (`OduncID`) REFERENCES `ODUNC` (`ID`);

--
-- Tablo kısıtlamaları `KITAP`
--
ALTER TABLE `KITAP`
  ADD CONSTRAINT `KITAP_ibfk_1` FOREIGN KEY (`KategoriID`) REFERENCES `KATEGORI` (`ID`);

--
-- Tablo kısıtlamaları `ODUNC`
--
ALTER TABLE `ODUNC`
  ADD CONSTRAINT `ODUNC_ibfk_1` FOREIGN KEY (`UyeID`) REFERENCES `UYE` (`ID`),
  ADD CONSTRAINT `ODUNC_ibfk_2` FOREIGN KEY (`KitapID`) REFERENCES `KITAP` (`ID`),
  ADD CONSTRAINT `ODUNC_ibfk_3` FOREIGN KEY (`VerenKullaniciID`) REFERENCES `KULLANICI` (`ID`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;


----------------------------------------------------------------------------------------------------------------------------------------------------------------------
--
-- Tablo döküm verisi `CEZA`
--

INSERT INTO `CEZA` (`ID`, `UyeID`, `OduncID`, `Tutar`, `OlusturmaTarihi`, `Aciklama`) VALUES
(3, 4, 23, 25.50, '2025-12-31 11:00:13', 'Kitap teslim tarihi 10 gün gecikti.'),
(4, 6, 24, 55.00, '2025-12-31 11:14:32', 'Kitap teslim tarihi 10 gün gecikti.'),
(5, 1, 28, 50.00, '2025-12-31 12:01:07', '5 gün gecikti.'),
(6, 4, 27, 60.00, '2026-01-01 19:27:40', '6 gün gecikti.'),
(7, 1, 32, 100.00, '2026-01-01 19:47:26', '10 gün gecikti.'),
(8, 5, 33, 140.00, '2026-01-05 17:48:44', '14 gün gecikti.'),
(9, 1, 38, 40.00, '2026-01-09 19:13:23', '4 gün gecikti.'),
(10, 1, 39, 550.00, '2026-01-09 19:30:29', '55 gün gecikti.');

--
-- Tablo döküm verisi `ISLEM_LOG`
--

INSERT INTO `ISLEM_LOG` (`ID`, `KullaniciAdi`, `IslemTuru`, `Aciklama`, `Tarih`) VALUES
(1, '1', 'Ödünç Verme', 'Kitap ID: 1 verildi. Üye ID: 1', '2025-12-27 12:28:19'),
(2, '1', 'Ödünç Verme', 'Kitap ID: 2 verildi. Üye ID: 3', '2025-12-27 12:43:00'),
(3, '1', 'Ödünç Verme', 'Kitap ID: 1 verildi. Üye ID: 1', '2025-12-27 12:43:17'),
(4, '1', 'Ödünç Verme', 'Kitap ID: 4 verildi. Üye ID: 5', '2025-12-27 13:03:07'),
(5, '1', 'Ödünç Verme', 'Kitap ID: 3 verildi. Üye ID: 2', '2025-12-27 13:05:07'),
(6, '1', 'Ödünç Verme', 'Kitap ID: 3 verildi. Üye ID: 4', '2025-12-27 13:08:45'),
(7, '1', 'Ödünç Verme', 'Kitap ID: 2 verildi. Üye ID: 1', '2025-12-27 13:10:00'),
(8, '1', 'Ödünç Verme', 'Kitap ID: 3 verildi. Üye ID: 5', '2025-12-27 13:19:35'),
(9, '1', 'Ödünç Verme', 'Kitap ID: 2 verildi. Üye ID: 5', '2025-12-27 13:19:54'),
(10, 'Sistem', 'İade Alma', 'Kitap ID: 3 iade alındı.', '2025-12-27 20:31:30'),
(11, 'Sistem', 'İade Alma', 'Kitap ID: 1 iade alındı.', '2025-12-27 20:52:11'),
(12, '1', 'Ödünç Verme', 'Kitap ID: 1 verildi. Üye ID: 1', '2025-12-27 20:53:07'),
(13, 'Sistem', 'İade Alma', 'Kitap ID: 3 iade alındı.', '2025-12-27 20:59:55'),
(14, 'Sistem', 'İade Alma', 'Kitap ID: 4 iade alındı.', '2025-12-27 21:02:26'),
(15, '1', 'Ödünç Verme', 'Kitap ID: 4 verildi. Üye ID: 4', '2025-12-27 21:05:21'),
(16, 'Sistem', 'İade Alma', 'Kitap ID: 2 iade alındı.', '2025-12-27 21:06:00'),
(17, 'Sistem', 'İade Alma', 'Kitap ID: 1 iade alındı.', '2025-12-27 21:17:26'),
(18, 'Sistem', 'İade Alma', 'Kitap ID: 3 iade alındı.', '2025-12-27 21:19:35'),
(19, 'Sistem', 'İade Alma', 'Kitap ID: 2 iade alındı.', '2025-12-27 21:28:04'),
(20, '1', 'Ödünç Verme', 'Kitap ID: 2 verildi. Üye ID: 3', '2025-12-27 21:35:32'),
(21, 'Sistem', 'İade Alma', 'Kitap ID: 2 iade alındı.', '2025-12-27 21:36:02'),
(22, 'Sistem', 'İade Alma', 'Kitap ID: 2 iade alındı.', '2025-12-27 21:36:56'),
(23, '1', 'Ödünç Verme', 'Kitap ID: 2 verildi. Üye ID: 4', '2025-12-27 21:39:16'),
(24, '1', 'Ödünç Verme', 'Kitap ID: 5 verildi. Üye ID: 1', '2025-12-27 21:39:25'),
(25, 'Sistem', 'İade Alma', 'Kitap ID: 5 iade alındı.', '2025-12-27 21:39:37'),
(26, '1', 'Ödünç Verme', 'Kitap ID: 3 verildi. Üye ID: 5', '2025-12-28 12:12:52'),
(27, '1', 'Ödünç Verme', 'Kitap ID: 3 verildi. Üye ID: 4', '2025-12-28 12:13:30'),
(28, 'Sistem', 'İade Alma', 'Kitap ID: 3 iade alındı.', '2025-12-28 12:18:17'),
(29, 'Sistem', 'Ceza Kesildi', 'Üye ID: 1 - Tutar: 25.50', '2025-12-28 17:11:50'),
(30, '1', 'Ödünç Verme', 'Kitap ID: 2 verildi. Üye ID: 6', '2025-12-29 12:02:25'),
(31, '1', 'Ödünç Verme', 'Kitap ID: 1 verildi. Üye ID: 1', '2025-12-29 13:29:21'),
(32, '1', 'Ödünç Verme', 'Kitap ID: 5 verildi. Üye ID: 3', '2025-12-29 13:29:57'),
(33, 'Sistem', 'İade Alma', 'Kitap ID: 4 iade alındı.', '2025-12-29 13:30:18'),
(34, '1', 'Ödünç Verme', 'Kitap ID: 4 verildi. Üye ID: 3', '2025-12-29 14:24:11'),
(35, '1', 'Ödünç Verme', 'Kitap ID: 3 verildi. Üye ID: 6', '2025-12-30 13:25:58'),
(36, 'Sistem', 'İade Alma', 'Kitap ID: 3 iade alındı.', '2025-12-30 17:15:26'),
(37, '1', 'Ödünç Verme', 'Kitap ID: 6 verildi. Üye ID: 5', '2025-12-30 20:33:15'),
(38, '1', 'Ödünç Verme', 'Kitap ID: 7 verildi. Üye ID: 5', '2025-12-30 20:33:22'),
(39, 'Sistem', 'Ceza Kesildi', 'Üye ID: 4 - Tutar: 25.50', '2025-12-31 11:00:13'),
(40, '1', 'Ödünç Verme', 'Kitap ID: 3 verildi. Üye ID: 4', '2025-12-31 11:01:14'),
(41, 'Sistem', 'İade Alma', 'Kitap ID: 2 iade alındı.', '2025-12-31 11:10:32'),
(42, 'Sistem', 'İade Alma', 'Kitap ID: 3 iade alındı.', '2025-12-31 11:10:36'),
(43, 'Sistem', 'Ceza Kesildi', 'Üye ID: 6 - Tutar: 55.00', '2025-12-31 11:14:32'),
(44, '1', 'Ödünç Verme', 'Kitap ID: 5 verildi. Üye ID: 2', '2025-12-31 11:30:44'),
(45, '1', 'Ödünç Verme', 'Kitap ID: 2 verildi. Üye ID: 3', '2025-12-31 11:33:22'),
(46, 'Sistem', 'İade Alma', 'Kitap ID: 5 iade alındı.', '2025-12-31 11:35:33'),
(47, NULL, 'Ödünç Verme', 'Kitap ID: 1 verildi. Üye ID: 4', '2025-12-31 11:52:13'),
(48, NULL, 'Ödünç Verme', 'Kitap ID: 1 verildi. Üye ID: 1', '2025-12-31 11:53:14'),
(49, 'Sistem', 'İade Alma', 'Kitap ID: 1 iade alındı.', '2025-12-31 12:00:47'),
(50, 'Sistem', 'İade Alma', 'Kitap ID: 1 iade alındı.', '2025-12-31 12:01:07'),
(51, 'Sistem', 'Ceza Kesildi', 'Üye ID: 1 - Tutar: 50.00', '2025-12-31 12:01:07'),
(52, '1', 'Ödünç Verme', 'Kitap ID: 5 verildi. Üye ID: 5', '2026-01-01 18:31:20'),
(53, '1', 'Ödünç Verme', 'Kitap ID: 6 verildi. Üye ID: 1', '2026-01-01 18:38:55'),
(54, 'Sistem', 'İade Alma', 'Kitap ID: 6 iade alındı.', '2026-01-01 19:25:32'),
(55, 'Sistem', 'İade Alma', 'Kitap ID: 1 iade alındı.', '2026-01-01 19:27:40'),
(56, 'Sistem', 'Ceza Kesildi', 'Üye ID: 4 - Tutar: 60.00', '2026-01-01 19:27:40'),
(57, NULL, 'Ödünç Verme', 'Kitap ID: 1 verildi. Üye ID: 1', '2026-01-01 19:46:41'),
(58, 'Sistem', 'İade Alma', 'Kitap ID: 1 iade alındı.', '2026-01-01 19:47:26'),
(59, 'Sistem', 'Ceza Kesildi', 'Üye ID: 1 - Tutar: 100.00', '2026-01-01 19:47:26'),
(60, NULL, 'Ödünç Verme', 'Kitap ID: 1 verildi. Üye ID: 5', '2026-01-01 19:59:28'),
(61, '1', 'Ödünç Verme', 'Kitap ID: 9 verildi. Üye ID: 3', '2026-01-03 20:35:24'),
(62, 'Sistem', 'İade Alma', 'Kitap ID: 7 iade alındı.', '2026-01-05 17:34:04'),
(63, 'Sistem', 'İade Alma', 'Kitap ID: 1 iade alındı.', '2026-01-05 17:48:44'),
(64, 'Sistem', 'Ceza Kesildi', 'Üye ID: 5 - Tutar: 140.00', '2026-01-05 17:48:44'),
(65, 'Sistem', 'İade Alma', 'Kitap ID: 4 iade alındı.', '2026-01-05 17:52:49'),
(66, '1', 'Ödünç Verme', 'Kitap ID: 14 verildi. Üye ID: 1', '2026-01-09 18:26:13'),
(67, 'Sistem', 'İade Alma', 'Kitap ID: 14 iade alındı.', '2026-01-09 18:26:19'),
(68, '1', 'Ödünç Verme', 'Kitap ID: 3 verildi. Üye ID: 3', '2026-01-09 18:42:36'),
(69, '1', 'Ödünç Verme', 'Kitap ID: 4 verildi. Üye ID: 4', '2026-01-09 18:43:03'),
(70, NULL, 'Ödünç Verme', 'Kitap ID: 1 verildi. Üye ID: 1', '2026-01-09 19:06:51'),
(71, NULL, 'Ödünç Verme', 'Kitap ID: 2 verildi. Üye ID: 1', '2026-01-09 19:08:50'),
(72, 'Sistem', 'İade Alma', 'Kitap ID: 1 iade alındı.', '2026-01-09 19:13:23'),
(73, 'Sistem', 'Ceza Kesildi', 'Üye ID: 1 - Tutar: 40.00', '2026-01-09 19:13:23'),
(74, 'Sistem', 'İade Alma', 'Kitap ID: 2 iade alındı.', '2026-01-09 19:13:35'),
(75, '1', 'Ödünç Verme', 'Kitap ID: 1 verildi. Üye ID: 4', '2026-01-09 19:17:42'),
(76, 'Sistem', 'İade Alma', 'Kitap ID: 3 iade alındı.', '2026-01-09 19:18:11'),
(77, NULL, 'Ödünç Verme', 'Kitap ID: 3 verildi. Üye ID: 1', '2026-01-09 19:27:17'),
(78, 'Sistem', 'İade Alma', 'Kitap ID: 2 iade alındı.', '2026-01-09 19:30:29'),
(79, 'Sistem', 'Ceza Kesildi', 'Üye ID: 1 - Tutar: 550.00', '2026-01-09 19:30:29');

-- --------------------------------------------------------

--
-- Tablo döküm verisi `KATEGORI`
--

INSERT INTO `KATEGORI` (`ID`, `Ad`) VALUES
(1, 'Roman'),
(2, 'Bilim'),
(3, 'Tarih'),
(4, 'Felsefe'),
(6, 'Psi̇koloji̇'),
(8, 'Mühendislik');

-- --------------------------------------------------------
--
-- Tablo döküm verisi `KITAP`
--

INSERT INTO `KITAP` (`ID`, `KitapAdi`, `Yazar`, `Yayinevi`, `BasimYili`, `KategoriID`, `ToplamAdet`, `MevcutAdet`) VALUES
(1, 'Tutunamayanlar', 'Oğuz Atay', 'Can', 2010, 1, 10, 9),
(2, 'Yaşamak', 'Yu Hua', 'Koridor', 1993, 1, 47, 46),
(3, 'Cesur Yeni Dünya', 'Aldous Huxley', 'İthaki', 2015, 1, 20, 18),
(4, 'İmparatorluktan Cumhuriyete', 'Halil İnalcık', 'Kronik', 2020, 3, 1, 0),
(5, 'İrade Terbiyesi', 'Jules Payot', 'Yakamoz', 2025, 4, 28, 26),
(6, 'Atomik Alışkanlıkl', 'James Clear', 'Pegasus', 2025, 6, 24, 23),
(7, 'Martin Eden', 'Jack London', 'İş Bankası', 2019, 1, 3, 3),
(9, 'Gece Yarısı Kütüphanesi', 'Matt Haig', 'Domingo', 2010, 1, 31, 30),
(10, 'Fahrenheit 451', 'Ray Bradbury', 'İthaki', 2018, 2, 5, 5),
(15, 'İnsan Ne İle Yaşar?', 'Tolstoy', 'Iş', 2010, 4, 25, 25);

-- --------------------------------------------------------
--
-- Tablo döküm verisi `KULLANICI`
--

INSERT INTO `KULLANICI` (`ID`, `KullaniciAdi`, `Sifre`, `AdSoyad`, `Rol`) VALUES
(1, 'admin', '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4', 'Sistem Yöneticisi', 'Admin');

-- --------------------------------------------------------


--
-- Tablo döküm verisi `ODUNC`
--

INSERT INTO `ODUNC` (`ID`, `UyeID`, `KitapID`, `VerenKullaniciID`, `OduncTarihi`, `SonTeslimTarihi`, `TeslimTarihi`) VALUES
(1, 1, 1, 1, '2025-12-27 00:00:00', '2026-01-11 00:00:00', '2025-12-27 00:00:00'),
(2, 3, 2, 1, '2025-12-27 00:00:00', '2026-01-11 00:00:00', '2025-12-27 00:00:00'),
(4, 5, 4, 1, '2025-12-27 00:00:00', '2026-01-11 00:00:00', '2025-12-27 00:00:00'),
(5, 2, 3, 1, '2025-12-27 00:00:00', '2026-01-11 00:00:00', '2025-12-27 00:00:00'),
(6, 4, 3, 1, '2025-12-27 00:00:00', '2026-01-11 00:00:00', '2025-12-27 00:00:00'),
(7, 1, 2, 1, '2025-12-27 00:00:00', '2026-01-11 00:00:00', '2025-12-27 00:00:00'),
(8, 5, 3, 1, '2025-12-27 00:00:00', '2026-01-11 00:00:00', '2025-12-27 00:00:00'),
(9, 5, 2, 1, '2025-12-27 00:00:00', '2026-01-11 00:00:00', '2025-12-27 00:00:00'),
(10, 1, 1, 1, '2025-12-27 00:00:00', '2026-01-11 00:00:00', '2025-12-27 00:00:00'),
(11, 4, 4, 1, '2025-12-27 00:00:00', '2026-01-11 00:00:00', '2025-12-29 00:00:00'),
(12, 3, 2, 1, '2025-12-27 00:00:00', '2026-01-11 00:00:00', '2025-12-27 00:00:00'),
(13, 4, 2, 1, '2025-12-27 00:00:00', '2026-01-11 00:00:00', '2025-12-31 00:00:00'),
(14, 1, 5, 1, '2025-12-27 00:00:00', '2026-01-11 00:00:00', '2025-12-27 00:00:00'),
(15, 5, 3, 1, '2025-12-28 00:00:00', '2026-01-12 00:00:00', '2025-12-30 00:00:00'),
(16, 4, 3, 1, '2025-12-28 00:00:00', '2026-01-12 00:00:00', '2025-12-28 00:00:00'),
(17, 6, 2, 1, '2025-12-29 00:00:00', '2026-01-13 00:00:00', '2026-01-09 00:00:00'),
(18, 1, 1, 1, '2025-12-29 00:00:00', '2026-01-13 00:00:00', '2025-12-31 00:00:00'),
(19, 3, 5, 1, '2025-12-29 00:00:00', '2026-01-13 00:00:00', '2025-12-31 00:00:00'),
(20, 3, 4, 1, '2025-12-29 00:00:00', '2026-01-13 00:00:00', '2026-01-05 00:00:00'),
(21, 6, 3, 1, '2025-12-30 00:00:00', '2026-01-14 00:00:00', NULL),
(22, 5, 6, 1, '2025-12-30 00:00:00', '2026-01-14 00:00:00', NULL),
(23, 5, 7, 1, '2025-12-30 00:00:00', '2026-01-14 00:00:00', '2026-01-05 00:00:00'),
(24, 4, 3, 1, '2025-12-31 00:00:00', '2026-01-15 00:00:00', '2025-12-31 00:00:00'),
(25, 2, 5, 1, '2025-12-31 00:00:00', '2026-01-15 00:00:00', NULL),
(26, 3, 2, 1, '2025-12-31 00:00:00', '2026-01-15 00:00:00', NULL),
(27, 4, 1, NULL, '2025-12-16 00:00:00', '2025-12-26 00:00:00', '2026-01-01 00:00:00'),
(28, 1, 1, NULL, '2025-12-16 00:00:00', '2025-12-26 00:00:00', '2025-12-31 00:00:00'),
(30, 5, 5, 1, '2026-01-01 00:00:00', '2026-01-16 00:00:00', NULL),
(31, 1, 6, 1, '2026-01-01 00:00:00', '2026-01-16 00:00:00', '2026-01-01 00:00:00'),
(32, 1, 1, NULL, '2025-12-07 00:00:00', '2025-12-22 00:00:00', '2026-01-01 00:00:00'),
(33, 5, 1, NULL, '2025-12-07 00:00:00', '2025-12-22 00:00:00', '2026-01-05 00:00:00'),
(34, 3, 9, 1, '2026-01-03 00:00:00', '2026-01-18 00:00:00', NULL),
(36, 3, 3, 1, '2026-01-09 00:00:00', '2026-01-24 00:00:00', '2026-01-09 00:00:00'),
(37, 4, 4, 1, '2026-01-09 00:00:00', '2026-01-24 00:00:00', NULL),
(38, 1, 1, NULL, '2025-12-25 00:00:00', '2026-01-05 00:00:00', '2026-01-09 00:00:00'),
(39, 1, 2, NULL, '2025-11-01 00:00:00', '2025-11-15 00:00:00', '2026-01-09 00:00:00'),
(40, 4, 1, 1, '2026-01-09 00:00:00', '2026-01-24 00:00:00', NULL),
(41, 1, 3, NULL, '2025-11-01 00:00:00', '2025-11-15 00:00:00', NULL);


--
-- Tablo döküm verisi `UYE`
--

INSERT INTO `UYE` (`ID`, `Ad`, `Soyad`, `Email`, `Telefon`, `ToplamBorc`, `KayitTarihi`) VALUES
(1, 'zeynep', 'önder', 'zeyneponder@gmail.com', '11111112', 740.00, '2025-12-26 01:26:44'),
(2, 'tahsin', 'önder', 'tahsinonder@gmail.com', '2222222', 0.00, '2025-12-26 20:11:47'),
(3, 'fatma', 'önder', 'fatmaonder@gmail.com', '333333333', 0.00, '2025-12-26 21:09:25'),
(4, 'ali', 'veli', 'aliveli@gmail.com', '99999', 85.50, '2025-12-26 22:08:43'),
(5, 'yunus', 'emre', 'yunusemra@hotmail.com', '99999999', 140.00, '2025-12-26 22:20:03'),
(6, 'sena', 'melek', 'senamelek@gmail.com', '88888888', 55.00, '2025-12-27 13:55:29'),
(8, 'ceren', 'yağmur', 'cerenkoc@mail.com', '7777777777', 0.00, '2025-12-30 20:28:49'),
(10, 'zec', 'dd', 'mail.', '544', 0.00, '2026-01-09 17:34:40'),
(11, 'zz', 'dd', 'f@gmail.com', '333', 0.00, '2026-01-09 17:36:50');
