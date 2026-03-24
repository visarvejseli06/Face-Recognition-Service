#!/bin/bash
# Autor: Visar Vejseli
# Datum: 24.03.2026
# Beschreibung: Vollautomatisiertes Setup für den AWS Face Recognition Service

echo "=========================================="
echo "🚀 Starte AWS Face Recognition Setup..."
echo "=========================================="

# 1. Variablen definieren 
INITIALS="visach" 
IN_BUCKET="mod346-in-bucket-$INITIALS"
OUT_BUCKET="mod346-out-bucket-$INITIALS"
ROLE_NAME="mod346-lambda-role-$INITIALS"
LAMBDA_NAME="mod346-face-rekognition-$INITIALS"

# AWS Account ID automatisch auslesen
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 2. S3 Buckets erstellen
echo "🪣 Erstelle S3 Buckets..."
aws s3 mb s3://$IN_BUCKET
aws s3 mb s3://$OUT_BUCKET

# 3. IAM Role für Lambda erstellen (Trust Policy)
echo "🔑 Erstelle IAM Berechtigungen..."
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Erstelle die Rolle
aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://trust-policy.json > /dev/null 2>&1

echo "⏳ Warte kurz, bis AWS die Rolle verarbeitet hat (10 Sekunden)..."
sleep 10

# Richtlinien anheften (S3 Zugriff, Rekognition Zugriff, und CloudWatch Logs)
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonRekognitionFullAccess
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)

# 4. Python-Code zippen
echo "📦 Verpacke Lambda-Code..."
cd ../src
zip -r ../scripts/lambda_function.zip lambda_function.py > /dev/null
cd ../scripts

# 5. Lambda Funktion erstellen
echo "⚡ Erstelle Lambda Funktion..."
# Hier wird die Umgebungsvariable OUTPUT_BUCKET an den Python-Code übergeben!
aws lambda create-function \
    --function-name $LAMBDA_NAME \
    --runtime python3.12 \
    --role $ROLE_ARN \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://lambda_function.zip \
    --environment Variables={OUTPUT_BUCKET=$OUT_BUCKET} > /dev/null 2>&1

echo "⏳ Warte auf Lambda-Bereitstellung (5 Sekunden)..."
sleep 5

# 6. Berechtigung für S3 hinzufügen, damit es Lambda triggern darf
aws lambda add-permission \
    --function-name $LAMBDA_NAME \
    --principal s3.amazonaws.com \
    --statement-id s3invoke \
    --action "lambda:InvokeFunction" \
    --source-arn arn:aws:s3:::$IN_BUCKET \
    --source-account $ACCOUNT_ID > /dev/null 2>&1

# 7. S3 Event-Trigger auf den In-Bucket setzen
echo "🔗 Verknüpfe S3 Uploads mit Lambda..."
LAMBDA_ARN=$(aws lambda get-function --function-name $LAMBDA_NAME --query 'Configuration.FunctionArn' --output text)

cat > notification.json <<EOF
{
  "LambdaFunctionConfigurations": [
    {
      "Id": "FaceRecognitionTrigger",
      "LambdaFunctionArn": "$LAMBDA_ARN",
      "Events": ["s3:ObjectCreated:*"]
    }
  ]
}
EOF

aws s3api put-bucket-notification-configuration --bucket $IN_BUCKET --notification-configuration file://notification.json

# Aufräumen lokaler Temp-Dateien
rm trust-policy.json notification.json lambda_function.zip

# 8. Abschluss und Ausgabe der Komponenten (Gütestufe 3 Anforderung!)
echo "=========================================="
echo "✅ Setup erfolgreich abgeschlossen!"
echo "Verwendete Komponenten:"
echo "- In-Bucket:  $IN_BUCKET"
echo "- Out-Bucket: $OUT_BUCKET"
echo "- IAM Role:   $ROLE_NAME"
echo "- Lambda:     $LAMBDA_NAME"
echo "=========================================="