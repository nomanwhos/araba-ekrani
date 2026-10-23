"""English for every Turkish UI string (keys are the Turkish source text).
Run `python3 scripts/l10n.py` after editing; it lists anything missing."""

EN = {
    # Brand and service names stay as they are.
    "Torpido": "Torpido", "Netflix": "Netflix", "Prime Video": "Prime Video", "Disney+": "Disney+",
    "Instagram": "Instagram", "Infuse": "Infuse", "Jellyfin": "Jellyfin", "Emby": "Emby", "Plex": "Plex",
    "Xtream": "Xtream", "%@: %@": "%@: %@",

    # Tabs and titles
    "Ana Sayfa": "Home", "Favoriler": "Favourites", "Perde": "Screen", "Ayarlar": "Settings",
    "Kaynaklar": "Sources", "Tarayıcı": "Browser", "Uygulamadan gönder": "Send from an app",
    "Kanallar": "Channels", "Videolar": "Videos", "Bölüm": "Section", "Durum": "Status",

    # Common actions
    "Ekle": "Add", "Sil": "Delete", "Vazgeç": "Cancel", "Kaydet": "Save", "Tamam": "Done", "Geri": "Back",
    "İleri": "Forward", "Durdur": "Stop", "Yenile": "Refresh", "Adlandır": "Rename", "Çıkar": "Remove",
    "Favori": "Favourite", "Tekrar dene": "Try again", "Oynat": "Play", "Duraklat": "Pause",
    "Sığdır": "Fit", "Doldur": "Fill", "Ad": "Name",

    # Home and search
    "Kaynak ekle": "Add source", "Henüz kanal yok": "No channels yet",
    "Bir M3U bağlantısı ekleyin, kanallar burada gruplarıyla listelenir.":
        "Add an M3U link and its channels appear here, grouped.",
    "Açık kanal yok": "No live channels",
    "Eklediğiniz listelerde şu an çalışan kanal bulunamadı. Ayarlar › Kaynaklar'dan listeyi yenileyin.":
        "None of the channels in your lists are working right now. Refresh the list in Settings › Sources.",
    "Kanallar okunamadı": "Couldn't read the channels",
    "Medya sunucuları": "Media servers", "Diğer": "Other",
    "Kanal ara": "Search channels", "Geçmişi temizle": "Clear history", "Sonuç yok": "No results",
    "“%@” adında kanal bulunamadı. Daha kısa ya da farklı bir kelime deneyin.":
        "No channel called “%@”. Try a shorter or different word.",
    "%@, %lld kanal": "%@, %lld channels", "Gruptaki tüm kanalları gösterir": "Shows every channel in the group",
    "%lld ms": "%lld ms", "Gecikme %lld milisaniye": "Latency %lld milliseconds",
    "Yayın şu an kapalı": "Stream is down right now", "Kanal %@": "Channel %@", "Kanal listesi": "Channel list",

    # Favourites and local videos
    "Favori yok": "No favourites",
    "Bir kanala basılı tutup Favorilere ekle'yi seçin, ya da oynatırken yıldıza dokunun.":
        "Press and hold a channel and choose Add to Favourites, or tap the star while it plays.",
    "Favorilere ekle": "Add to Favourites", "Favorilerden çıkar": "Remove from Favourites",
    "Video yok": "No videos",
    "Dosyalar'dan ya da Fotoğraflar'dan video ekleyin; internet olmadan da oynar.":
        "Add videos from Files or Photos; they play without internet.",
    "Dosyalar": "Files", "Fotoğraflar": "Photos", "Video kopyalanıyor…": "Copying video…",
    "Videoyu adlandır": "Rename video", "Fotoğraflar videosu": "Photos video",
    "Telefonda yer yok: bu video için yaklaşık %lld MB gerekiyor.":
        "Not enough space: this video needs about %lld MB more.",
    "Video okunamadı. Dosya bozuk olabilir ya da iCloud'dan henüz inmemiş olabilir.":
        "Couldn't read the video. The file may be damaged or not yet downloaded from iCloud.",

    # Player
    "Oynatıcıyı küçült": "Minimise player", "Oynatıcıyı açar": "Opens the player",
    "Görüntüyü sığdır": "Fit picture", "Görüntüyü ekrana doldur": "Fill the screen",
    "Bu kanalın oynatılabilir bir adresi yok.": "This channel has no playable address.",
    "Bu yayın açılmadı. Kaynak kapalı olabilir ya da biçimi desteklenmiyor.":
        "This stream didn't open. The source may be down or its format isn't supported.",
    "Video dosyası bulunamadı. Videolar listesinden silip yeniden içe aktarın.":
        "Video file not found. Delete it from Videos and import it again.",
    "Sunucu oturumu bulunamadı. Ayarlar › Kaynaklar'dan sunucuyu yeniden ekleyin.":
        "Server session not found. Add the server again in Settings › Sources.",
    "Sunucu oturumu bulunamadı. Ayarlar › Kaynaklar'dan sunucuyu silip yeniden ekleyin.":
        "Server session not found. Delete the server in Settings › Sources and add it again.",

    # Media server browser
    "Sunucu açılmadı": "Couldn't open the server", "Burada bir şey yok": "Nothing here",
    "Bu klasörde oynatılabilir video bulunamadı.": "No playable videos in this folder.",
    " izlendi": " watched",

    # Perde (mirroring)
    "Arabaya bağlı değil": "Not connected to the car", "Perde hazır": "Screen ready", "Yayında": "Live",
    "iPhone'u CarPlay'e bağlayın. Torpido araba ekranında da açılır.":
        "Connect your iPhone to CarPlay. Torpido opens on the car screen too.",
    "Aşağıdaki düğmeye dokunun, açılan pencerede Yayını Başlat'ı seçin.":
        "Tap the button below, then choose Start Broadcast in the window that opens.",
    "İzlemek istediğiniz uygulamaya geçin.": "Switch to the app you want to watch.",
    "Bağlı": "Connected", "Bağlı değil": "Not connected", "Yayın": "Broadcast", "Açık": "On", "Kapalı": "Off",
    "Kare hızı": "Frame rate", "%lld kare/sn": "%lld fps",
    "Sadece yolcuyken ya da araç park halindeyken kullanın. Araç kullanırken izlemeyin.":
        "Use only as a passenger or while parked. Never watch while driving.",
    "YouTube gibi siteleri Torpido'da açın ya da hangi uygulamanın arabaya nasıl gideceğine bakın.":
        "Open sites like YouTube in Torpido, or see how each app can reach the car.",
    "Yansıtmayı Başlat": "Start Mirroring", "Yansıtmayı Durdur": "Stop Mirroring",
    "Telefonda Torpido'yu açın ve Yansıtmayı Başlat'a dokunun.": "Open Torpido on your phone and tap Start Mirroring.",
    "Alıcı başlatılamadı: %@": "Couldn't start the receiver: %@",

    # Browser
    "Adres ya da arama": "Address or search", "Hızlı başlangıç": "Quick start", "Yer imleri": "Bookmarks",
    "Yer imi ekle": "Add bookmark", "Yer iminden çıkar": "Remove bookmark",
    "Netflix ve Prime Video iPhone'da tarayıcıda oynatmaz ve korumalı videoları yansıtmada siyah görünür. YouTube ve korumasız siteler çalışır.":
        "Netflix and Prime Video won't play in a browser on iPhone, and their protected videos are black when mirrored. YouTube and unprotected sites work.",

    # Cast guide
    "Torpido'nun alıcı olarak görünmesi (DLNA) Apple'ın ağ iznini bekliyor. O zamana kadar her uygulama Perde ile yansıtılabilir; korumalı olanlar hariç.":
        "Showing up as a receiver (DLNA) is waiting for Apple's network permission. Until then, any app except protected ones can be mirrored with Screen.",
    "Kendi Gönder düğmesiyle (DLNA)": "With its own Cast button (DLNA)", "Perde ile yansıtın": "Mirror with Screen",
    "Korumalı: arabada görüntü siyah kalır": "Protected: the picture stays black in the car",
    "%@ bu iPhone'da yüklü değil.": "%@ isn't installed on this iPhone.", "%@ uygulamasını aç": "Open %@",
    "Önce Perde'de Yansıtmayı Başlat'a dokunun.": "First tap Start Mirroring in Screen.",
    "%@ uygulamasını açıp videoyu oynatın; telefon ekranı arabada görünür.":
        "Open %@ and play the video; your phone screen appears in the car.",
    "Ses telefondan arabaya her zamanki gibi gelir.": "Sound comes from the phone to the car as usual.",
    "%@ uygulamasında videoyu açıp Gönder (Cast) düğmesine dokunun.": "Open the video in %@ and tap its Cast button.",
    "Listeden Torpido'yu seçin. Bu adım Apple'ın ağ izni geldikten sonra çalışacak.":
        "Choose Torpido in the list. This step works once Apple grants the network permission.",
    "O zamana kadar Perde ile yansıtabilirsiniz.": "Until then you can mirror with Screen.",
    "%@ videolarını kopya korumasıyla (DRM) gönderir.": "%@ sends its videos with copy protection (DRM).",
    "Ekran yansıtmada görüntü siyah, ses açık kalır; bu, servisin kuralı.":
        "When mirrored, the picture is black and the sound stays on; that's the service's rule.",
    "Arabada izlemek için videoyu %@ uygulamasından indirip telefonda izleyin.":
        "To watch in the car, download the video in the %@ app and watch it on the phone.",

    # Settings
    "M3U listelerinizi ekleyin, yenileyin ya da silin.": "Add, refresh or delete your M3U lists.",
    "Araba ekranı": "Car screen",
    "Kapalıyken görüntü kenarlarda siyah boşlukla sığdırılır. Arabada sol üstteki düğmeyle de değiştirebilirsiniz.":
        "When off, the picture fits with black bars at the edges. You can also switch it with the top-left button in the car.",
    "Nasıl çalışır": "How it works",
    "Perde sekmesinde Yansıtmayı Başlat'a dokunun ve açılan pencerede Yayını Başlat'ı seçin.":
        "In the Screen tab, tap Start Mirroring and choose Start Broadcast in the window that opens.",
    "İzlemek istediğiniz uygulamaya geçin. Telefon ekranı arabada görünür.":
        "Switch to the app you want to watch. Your phone screen appears in the car.",
    "Bilinmesi gerekenler": "Good to know",
    "Ses, telefondaki uygulamadan arabaya her zamanki gibi gelir.": "Sound comes from the app on the phone to the car as usual.",
    "Araba ekranında kısa bir gecikme olabilir.": "There may be a short delay on the car screen.",
    "Araba ekranına dokunmak telefonu kontrol etmez.": "Touching the car screen doesn't control the phone.",
    "Netflix, Prime Video gibi korumalı videolar yansıtmada siyah görünür; bu, o servislerin koruması.":
        "Protected videos such as Netflix and Prime Video are black when mirrored; that's those services' protection.",
    "Hakkında": "About", "Sürüm": "Version", "Dil": "Language",
    "Uygulamanın dilini iPhone Ayarları'nda değiştirin.": "Change the app's language in iPhone Settings.",

    # Sources
    "Kaynak türü": "Source type", "Ad (isteğe bağlı)": "Name (optional)", "Örn. Ev listesi": "e.g. Home list",
    "Kaynağın adı": "Source name", "Liste bağlantısı": "List link", "M3U bağlantısı": "M3U link",
    "IPTV sağlayıcınızın verdiği .m3u ya da .m3u8 adresi. Torpido kanal içermez; liste sizin. Bağlantıdaki şifre iPhone'un anahtar zincirinde saklanır.":
        "The .m3u or .m3u8 address from your IPTV provider. Torpido has no channels of its own; the list is yours. Any password in the link is kept in the iPhone's keychain.",
    "Sunucu adresi": "Server address", "Kullanıcı adı": "Username", "Şifre": "Password",
    "Xtream hesabı": "Xtream account", "Jellyfin sunucusu": "Jellyfin server", "M3U listesi": "M3U list",
    "Sağlayıcınızın verdiği sunucu adresi, kullanıcı adı ve şifre. Şifre yalnızca bu iPhone'un anahtar zincirinde durur.":
        "The server address, username and password from your provider. The password stays only in this iPhone's keychain.",
    "Kendi Jellyfin sunucunuzun adresi ve hesabınız. Filmler ve diziler Ana Sayfa'daki sunucu satırından açılır.":
        "Your own Jellyfin server's address and account. Films and series open from the server row on Home.",
    "Bağlantıyı yapıştırın ya da QR kodunu okutun": "Paste the link or scan its QR code",
    "Sunucu adresi, kullanıcı adı ve şifre": "Server address, username and password",
    "Kendi sunucunuzun adresi ve hesabınız": "Your own server's address and account",
    "Plex hesabınızla giriş": "Sign in with your Plex account",
    "Kaynak yok": "No sources", "M3U bağlantınızı ekleyin; kanallar Ana Sayfa'da görünür.":
        "Add your M3U link; its channels appear on Home.",
    "Sola kaydırarak yenileyin ya da silin.": "Swipe left to refresh or delete.",
    "Kaynak silinsin mi?": "Delete this source?", "%@ listesini sil": "Delete %@",
    "Listenin kanalları, favorileri ve kaldığınız yerler de silinir.":
        "Its channels, favourites and resume points are deleted too.",
    "Silinemedi: %@": "Couldn't delete: %@", "Henüz indirilmedi": "Not downloaded yet", "Güncellendi: ": "Updated: ",

    # Errors
    "Bu bir bağlantı değil. http:// ya da https:// ile başlayan adresi yapıştırın.":
        "That isn't a link. Paste an address starting with http:// or https://.",
    "Liste indirilemedi (sunucu %lld döndürdü). Bağlantının süresi dolmuş olabilir.":
        "Couldn't download the list (the server returned %lld). The link may have expired.",
    "Liste indirilemedi. İnternet bağlantınızı ve adresi kontrol edin.":
        "Couldn't download the list. Check your internet connection and the address.",
    "Bu adres bir kanal listesi değil: içeriği #EXTM3U ile başlamıyor.":
        "This address isn't a channel list: its content doesn't start with #EXTM3U.",
    "Liste indirildi ama içinde oynatılabilir kanal yok.": "The list downloaded but has no playable channels.",
    "Sunucu adresi geçersiz. http:// ya da https:// ile başlayan adresi yazın (örn. http://sunucu.com:8080).":
        "Invalid server address. Enter one starting with http:// or https:// (e.g. http://server.com:8080).",
    "Sunucuya ulaşılamadı. Adresi, portu ve internet bağlantınızı kontrol edin.":
        "Couldn't reach the server. Check the address, the port and your internet connection.",
    "Kullanıcı adı ya da şifre yanlış.": "Wrong username or password.",
    "Hesap etkin değil (durum: %@). Sağlayıcınızla görüşün.": "The account isn't active (status: %@). Contact your provider.",
    "Sunucu bir hata döndürdü (%lld).": "The server returned an error (%lld).",
    "Sunucunun yanıtı anlaşılamadı. Bu bir Xtream ya da Jellyfin sunucusu mu?":
        "Couldn't understand the server's reply. Is this an Xtream or Jellyfin server?",
    # DLNA receiver
    "Wi-Fi'ye bağlı değil. Alıcı yalnızca aynı Wi-Fi ağındaki uygulamalara görünür.": 'Not connected to Wi-Fi. The receiver is only visible to apps on the same Wi-Fi network.',
    'Ağda görünme başlatılamadı: %@': 'Could not appear on the network: %@',
    'Alıcı başlatılamadı: %@': 'Could not start the receiver: %@',
    'Alıcı': 'Receiver',
    'Açıkken Torpido, aynı Wi-Fi ağındaki VLC, Plex gibi uygulamaların Gönder listesinde “Torpido (iPhone)” adıyla görünür. Arka planda da dinler; bunun için sessiz bir ses oturumu açık kalır ve pil biraz daha hızlı biter.': 'While on, Torpido appears as “Torpido (iPhone)” in the Cast list of apps such as VLC and Plex on the same Wi-Fi. It keeps listening in the background by holding a silent audio session, so the battery drains a little faster.',
    'Gönder düğmesi olmayan uygulamalar Perde ile yansıtılabilir; korumalı olanlar hariç.': 'Apps without a Cast button can be mirrored with Perde, except protected ones.',
    'Oynatılıyor: %@': 'Playing: %@',
    'Gönderilmesini bekliyor': 'Waiting for a cast',
    "Listeden Torpido'yu seçin. Alıcı açık olmalı ve iPhone ile aynı Wi-Fi ağında olmalı.": 'Pick Torpido from the list. The receiver must be on and on the same Wi-Fi as the iPhone.',
    "Video Torpido'da açılır; araba ekranında görmek için Perde'de yansıtmayı başlatın.": 'The video opens in Torpido; start mirroring in Perde to see it on the car screen.',
    'Kapalı': 'Off',
}
