#!/bin/bash

# Autor: Christopher Rossi

# Datum: 24.03.26

# Beschreibung: Test-Skript zum Hochladen eines Fotos und Auslesen der AWS Rekognition Ergebnisse.
 


INITIALS="visach" 

IN_BUCKET="mod346-in-bucket-$INITIALS"

OUT_BUCKET="mod346-out-bucket-$INITIALS"
 
# 1. Prüfen, ob beim Starten des Skripts ein Bild mitgegeben wurde

if [ -z "$1" ]; then

    echo "⚠️ Fehler: Du musst ein Bild zum Testen angeben!"

    echo "So rufst du das Skript auf: ./test.sh mein_bild.jpg"

    exit 1

fi
 
FILE_NAME=$(basename "$1")
 
echo "=========================================="

echo "🚀 Starte Testlauf für: $FILE_NAME"

echo "=========================================="
 
# 2. Bild in den In-Bucket hochladen (Das triggert die Lambda-Funktion von Person 1)

echo "📸 Lade Bild in den $IN_BUCKET hoch..."

aws s3 cp "$1" s3://$IN_BUCKET/ > /dev/null
 
# 3. Kurz warten, damit Lambda und AWS Rekognition Zeit haben, das Bild zu analysieren

echo "⏳ Warte 8 Sekunden auf die Gesichtserkennung..."

sleep 8
 
# 4. Das Ergebnis (JSON-Datei) aus dem Out-Bucket herunterladen

echo "📥 Lade Analyse-Ergebnis herunter..."

aws s3 cp s3://$OUT_BUCKET/$FILE_NAME.json ./result.json > /dev/null 2>&1
 
if [ ! -f ./result.json ]; then

    echo "❌ Fehler: Ergebnis-JSON wurde nicht gefunden. Lief die Lambda-Funktion fehlerfrei durch?"

    exit 1

fi
 
echo "=========================================="

echo "🔎 ERGEBNIS DER GESICHTSERKENNUNG:"
 
# 5. Benutzerfreundliche Ausgabe (Gütestufe 3 Anforderung!)

# Wir nutzen Python, um das JSON sauber auszulesen, da Python in eurer Umgebung sowieso läuft.

python3 -c "

import json

try:

    with open('result.json') as f:

        data = json.load(f)

        if data.get('CelebrityFaces'):

            for face in data['CelebrityFaces']:

                print(f'- 👤 Erkannte Person: {face[\"Name\"]}')

                print(f'  🎯 Wahrscheinlichkeit: {face[\"MatchConfidence\"]:.2f}%')

        else:

            print('- 🤷 Keine bekannte Persönlichkeit auf diesem Foto erkannt.')

except Exception as e:

    print('Fehler beim Auslesen der Daten:', e)

"

echo "=========================================="
 
# Aufräumen der lokalen Ergebnisdatei

rm result.json
 