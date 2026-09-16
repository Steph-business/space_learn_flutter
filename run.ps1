# Lance ou construit Space Learn avec sa configuration.
#
# POURQUOI CE SCRIPT EXISTE.
# L'adresse des serveurs ne figure plus dans les sources : le depot mobile est
# public, et une adresse ecrite en dur y serait figee pour toujours. Elle vit
# dans dart_define.json, qui n'est PAS suivi par Git — mais Flutter ne lit ce
# fichier que si on le lui passe. Un « flutter run » nu retombe donc sur
# « localhost » et ne joint rien : c'est le comportement voulu (mieux vaut
# echouer tout de suite que viser la production sans le savoir), mais il ne
# doit pas dependre du fait qu'on pense au drapeau a chaque lancement.
#
# USAGE
#   ./run.ps1              lance sur l'appareil connecte (debug)
#   ./run.ps1 apk          construit l'APK de debogage
#   ./run.ps1 release      construit l'APK de release, celui qu'on distribue
#   ./run.ps1 test         lance la suite de tests
#
# Tout argument supplementaire est transmis tel quel a Flutter :
#   ./run.ps1 -d emulator-5554
#
#   ./run.ps1 release -QuandMeme      construit sans poser la question du clair
#
# POURQUOI LA QUESTION EXISTE (voir plus bas, action 'release').
# main.dart avertit deja quand l'application vise une adresse publique en http,
# mais son avertissement commence par "if (!kDebugMode) return;" : il ne
# s'affiche qu'a "flutter run". Or tout ce qu'il dit s'adresse a la personne
# qui PUBLIE - reconstruire l'APK avant d'annoncer le HTTPS, sinon les
# telephones deja equipes continueront de parler en clair. Ce script est le
# seul endroit qui se trouve entre la decision et l'APK : le rappel est donc
# repris ici, ou il a un destinataire.

param(
    [Parameter(Position = 0)]
    [ValidateSet('run', 'apk', 'release', 'test')]
    [string]$Action = 'run',

    # Passe outre la question posee avant un release en clair. A n'utiliser que
    # lorsqu'on sait exactement pourquoi on distribue un APK qui parle http.
    [switch]$QuandMeme,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Reste
)

$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

$config = Join-Path $PSScriptRoot 'dart_define.json'

# Le fichier manquant est le seul cas ou l'on s'arrete : sans lui, tout ce qui
# suit echouerait plus loin, avec un message qui n'aurait plus rien a voir.
if (-not (Test-Path $config)) {
    Write-Host ''
    Write-Host '  dart_define.json est introuvable.' -ForegroundColor Red
    Write-Host ''
    Write-Host "  C'est le fichier qui porte l'adresse des serveurs. Il n'est"
    Write-Host '  pas suivi par Git : chaque poste a le sien. Pour le creer :'
    Write-Host ''
    Write-Host '      Copy-Item dart_define.example.json dart_define.json' -ForegroundColor Yellow
    Write-Host ''
    Write-Host "  puis remplacez-y l'adresse d'exemple par celle du serveur."
    Write-Host ''
    exit 1
}

$drapeau = "--dart-define-from-file=$config"

# Cette adresse est-elle celle d'un poste de developpement ?
#
# Meme regle que main.dart (_estUneAdresseDeDeveloppement), et pour la meme
# raison : le http vers localhost, l'emulateur ou un reseau prive ne sort pas de
# la machine ou du Wi-Fi. Le test porte sur des ADRESSES, pas sur des noms -
# "10.exemple.ci" est un domaine public parfaitement legal.
function Test-AdresseDeDeveloppement {
    param([string]$Hote)

    if ([string]::IsNullOrWhiteSpace($Hote)) { return $true }
    if ($Hote -in @('localhost', '127.0.0.1', '::1', '10.0.2.2', '10.0.3.2')) { return $true }
    if ($Hote.EndsWith('.local')) { return $true }

    $octets = $Hote.Split('.')
    if ($octets.Count -ne 4) { return $false }
    $nombres = @()
    foreach ($o in $octets) {
        $n = 0
        if (-not [int]::TryParse($o, [ref]$n)) { return $false }
        if ($n -lt 0 -or $n -gt 255) { return $false }
        $nombres += $n
    }

    if ($nombres[0] -eq 10) { return $true }
    if ($nombres[0] -eq 192 -and $nombres[1] -eq 168) { return $true }
    if ($nombres[0] -eq 172 -and $nombres[1] -ge 16 -and $nombres[1] -le 31) { return $true }
    return $false
}

# Les adresses configurees qui partiraient en clair vers une machine publique.
function Get-AdressesEnClair {
    param([string]$Fichier)

    try {
        $json = Get-Content -Path $Fichier -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        # Un dart_define.json illisible n'est pas notre sujet : flutter le dira
        # bien mieux, et deux lignes plus bas. On ne bloque pas la construction
        # sur une question qu'on ne sait pas poser.
        return @()
    }

    $enClair = @()
    foreach ($cle in @('API_BASE_URL', 'API_BASE_URL_GIN')) {
        $valeur = $json.$cle
        if ([string]::IsNullOrWhiteSpace($valeur)) { continue }
        $uri = $null
        if (-not [Uri]::TryCreate($valeur, [UriKind]::Absolute, [ref]$uri)) { continue }
        if ($uri.Scheme -ne 'http') { continue }
        if (Test-AdresseDeDeveloppement $uri.Host) { continue }
        $enClair += "$cle = $valeur"
    }
    return $enClair
}

switch ($Action) {
    'run' {
        Write-Host "Lancement avec $([IO.Path]::GetFileName($config))..." -ForegroundColor Cyan
        & flutter run $drapeau @Reste
    }
    'apk' {
        Write-Host 'Construction de l''APK de debogage...' -ForegroundColor Cyan
        & flutter build apk --debug $drapeau @Reste
    }
    'release' {
        # LE SEUL ENDROIT ENTRE LA DECISION ET L'APK.
        #
        # Un APK distribue fige son adresse : un certificat pose plus tard sur
        # le 443 ne rattrape PAS les telephones deja equipes, qui continueront
        # d'appeler les ports directs en clair - jetons, mots de passe, OTP -
        # jusqu'a leur mise a jour. La question se pose donc AVANT la
        # construction, et non apres.
        # Le @() force un tableau : PowerShell "deroule" un resultat unique en
        # simple chaine, et .Count n'aurait alors plus le sens attendu.
        $enClair = @(Get-AdressesEnClair $config)
        if ($enClair.Count -gt 0 -and -not $QuandMeme) {
            Write-Host ''
            Write-Host '  CET APK PARLERA EN CLAIR A UNE ADRESSE PUBLIQUE.' -ForegroundColor Red
            Write-Host ''
            foreach ($ligne in $enClair) {
                Write-Host "      $ligne" -ForegroundColor Yellow
            }
            Write-Host ''
            Write-Host '  Jetons de session, mots de passe et OTP y circuleront lisibles'
            Write-Host "  par qui ecoute le reseau, et le port direct court-circuite le"
            Write-Host '  proxy (plafond de televersement, limitation de debit, TLS).'
            Write-Host ''
            Write-Host '  Le jour du HTTPS : ecrire la MEME origine sans port dans les deux'
            Write-Host '  valeurs de dart_define.json (https://<domaine>), fermer le clair'
            Write-Host "  dans android/app/src/main/res/xml/network_security_config.xml -"
            Write-Host '  sa marche a suivre y est ecrite -, PUIS reconstruire et publier'
            Write-Host "  CET APK AVANT d'annoncer le passage. Un APK deja installe"
            Write-Host '  continuera d''appeler 8083/8084 en clair jusqu''a sa mise a jour.'
            Write-Host ''
            $reponse = Read-Host '  Construire quand meme ? (oui/non)'
            if ($reponse -notin @('oui', 'o', 'yes', 'y')) {
                Write-Host ''
                Write-Host '  Construction annulee.' -ForegroundColor Cyan
                Write-Host ''
                exit 1
            }
            Write-Host ''
        }

        Write-Host 'Construction de l''APK de release...' -ForegroundColor Cyan
        & flutter build apk --release $drapeau @Reste
        Write-Host ''
        Write-Host '  Verification : aucune cle de service ne doit rester dans l''APK.' -ForegroundColor Cyan
        Write-Host '      unzip -p build/app/outputs/flutter-apk/app-release.apk | grep -c service_role'
        Write-Host '  doit rendre 0.'
    }
    'test' {
        # Les tests ne touchent aucun serveur, mais le drapeau ne coute rien et
        # garde une seule facon de lancer le projet.
        & flutter test $drapeau @Reste
    }
}

exit $LASTEXITCODE
