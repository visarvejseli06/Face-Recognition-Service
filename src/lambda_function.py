"""
Autor: Sasa Radovanovic
Datum: 24.03.2026
Quelle 1 (Aufgabenstellung): https://docs.aws.amazon.com/rekognition/latest/dg/celebrities.html
Quelle 2 (Boto3 S3): https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3.html
 
Beschreibung:
Diese Lambda-Funktion wird automatisch getriggert, sobald ein Foto in den S3 In-Bucket hochgeladen wird.
Sie ruft den AWS Rekognition Dienst auf, um bekannte Persönlichkeiten auf dem Foto zu erkennen,
und speichert die detaillierte JSON-Antwort anschliessend im S3 Out-Bucket ab.
"""
 
import json
import urllib.parse
import boto3
import os
 
# AWS Clients für S3 und Rekognition initialisieren
rekognition = boto3.client('rekognition')
s3 = boto3.client('s3')
 
def lambda_handler(event, context):
    # Den Namen des Ziel-Buckets (Out-Bucket) aus den Umgebungsvariablen laden.
    # WICHTIG: Diese Variable setzen wir später im init.sh Skript!
    out_bucket = os.environ.get('OUTPUT_BUCKET')
    if not out_bucket:
        print("Fehler: OUTPUT_BUCKET Umgebungsvariable wurde nicht gesetzt!")
        return {"statusCode": 500, "body": "Configuration Error: Out-Bucket fehlt."}
 
    # Das Event kann theoretisch mehrere Dateien enthalten, wir iterieren durch alle
    for record in event['Records']:
        # Bucket-Namen und Dateinamen (Key) aus dem Upload-Event extrahieren
        in_bucket = record['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(record['s3']['object']['key'], encoding='utf-8')
        try:
            print(f"Starte Analyse fuer Bild: {key} aus Bucket: {in_bucket}")
            # 1. AWS Rekognition API aufrufen, um das Bild zu analysieren
            response = rekognition.recognize_celebrities(
                Image={
                    'S3Object': {
                        'Bucket': in_bucket,
                        'Name': key
                    }
                }
            )
            # 2. Dateinamen fuer die Ergebnis-Datei generieren (z.B. "jeff_bezos.jpg.json")
            out_key = f"{key}.json"
            # 3. Das JSON-Ergebnis sauber formatiert in den Out-Bucket speichern
            s3.put_object(
                Bucket=out_bucket,
                Key=out_key,
                Body=json.dumps(response, indent=4),
                ContentType='application/json'
            )
            print(f"Erfolg! JSON-Analyse gespeichert unter {out_bucket}/{out_key}")
        except Exception as e:
            print(f"Fehler bei der Verarbeitung der Datei {key}: {str(e)}")
            raise e
    # Rückmeldung an AWS Lambda, dass alles sauber durchgelaufen ist
    return {
        'statusCode': 200,
        'body': json.dumps('Face Recognition Analyse erfolgreich abgeschlossen!')
    }