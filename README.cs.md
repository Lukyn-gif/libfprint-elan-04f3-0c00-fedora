# ELAN 04f3:0c00 na Fedoře 44

Toto je experimentální sada úprav ovladače `libfprint` pro čtečku ELAN
`04f3:0c00`, revize `0281`. Byla vyzkoušena na HP Pavilion 15-eg0900nc.
Čtečka se zapojuje do systémových služeb `fprintd` a PAM; samostatná
„aplikace na otisk“ by přihlášení do systému nezajistila.

Na tomto notebooku se podařilo otisk zaregistrovat, ověřit výsledkem
`verify-match` a zachovat po restartu. Občas se však objevilo vypršení
USB přenosu nebo nerozpoznaný otisk. Nová verze na čtečce správně odlišila
uložený prst (`verify-match`) od jiného (`verify-no-match`). Větev opakování
po špatném snímku, kvůli které vznikala chyba dvojího hlášení, zatím nebyla
znovu vyvolána. S novou verzí fungovalo `sudo -v` i odemčení zamčené obrazovky
přes otisk bez přihlašovacího hesla. Nové přihlášení přes GDM ještě nebylo
ověřeno. Projekt proto není hotový ovladač pro každého uživatele.

## Instalace z tohoto repozitáře

```bash
bash elan-fprint.sh install
fprintd-list "$USER"
fprintd-verify -f right-index-finger
```

Pokud už je prst v seznamu, znovu ho neregistrujte. Příkaz
`fprintd-enroll -f right-index-finger` použijte pouze tehdy, když otisk
uložený není.
Registrace mění šablony uložené přímo ve čtečce a může zasáhnout i otisky
z Windows Hello, pokud je na stejném zařízení používáte.

Ponechte možnost přihlášení heslem. Příkaz `bash elan-fprint.sh rollback`
vrátí původní systémovou knihovnu; uložený otisk nemaže. Pokud už máte
nainstalovanou starší verzi tohoto projektu, nejdřív ji vraťte příkazem
`rollback` z jejího skriptu. Nový instalátor odmítne starou knihovnu
přepsat bez tohoto kroku.

Po přihlášení otiskem může GNOME požádat o heslo chráněné klíčenky.
Otisk nedodá heslo, kterým je klíčenka zašifrovaná. Projekt heslo
klíčenky nemění. Její nastavení na prázdné heslo by odstranilo dotaz,
ale uložená hesla by na tomto nešifrovaném disku při přístupu k disku
nebyla chráněna heslem klíčenky.

Podrobný postup, licence a zdroje převzatých úprav jsou v
[anglickém README](README.md). Před zveřejněním na GitHubu neukládejte
do repozitáře otisky, hesla ani syrové diagnostické záznamy.
