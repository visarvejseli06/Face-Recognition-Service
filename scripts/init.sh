#!/bin/bash
# Autor: Euer Team
# Datum: Heute
# Beschreibung: Setup für AWS Learner-Lab (us-east-1)

echo "=========================================="
echo "🚀 Starte AWS Face Recognition Setup..."
echo "=========================================="

# Zwinge AWS, die Region us-east-1 (Learner-Lab Standard) zu nutzen!
export AWS_DEFAULT_REGION="us-east-1"

INITIALS="visach" 
IN_BUCKET="mod346-in-bucket-$INITIALS"
OUT_BUCKET="mod346-out-bucket-$INITIALS"
LAMBDA_NAME="mod346-face-rekognition-$INITIALS"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "🪣 Erstelle S3 Buckets..."
aws s3 mb s3://$IN_BUCKET
aws s3 mb s3://$OUT_BUCKET

echo "🔑 Lade existierende LabRole..."
ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text 2>/dev/null)

if [ -z "$ROLE_ARN" ]; then
    echo "❌ Fehler: 'LabRole' wurde nicht gefunden. Ist das Learner-Lab aktiv?"
    exit 1
fi

echo "📦 Verpacke Lambda-Code..."
cd ../src
zip -r ../scripts/lambda_function.zip lambda_function.py > /dev/null
cd ../scripts

echo "⚡ Erstelle Lambda Funktion..."
aws lambda create-function \
    --function-name $LAMBDA_NAME \
    --runtime python3.12 \
    --role $ROLE_ARN \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://lambda_function.zip \
    --environment Variables={OUTPUT_BUCKET=$OUT_BUCKET} > /dev/null 2>&1

echo "⏳ Warte auf Lambda-Bereitstellung (5 Sekunden)..."
sleep 5

aws lambda add-permission \
    --function-name $LAMBDA_NAME \
    --principal s3.amazonaws.com \
    --statement-id s3invoke \
    --action "lambda:InvokeFunction" \
    --source-arn arn:aws:s3:::$IN_BUCKET \
    --source-account $ACCOUNT_ID > /dev/null 2>&1

echo "🔗 Verknüpfe S3 Uploads mit Lambda..."
LAMBDA_ARN=$(aws lambda get-function --function-name $LAMBDA_NAME --query 'Configuration.FunctionArn' --output text)

cat > notification.json <<INNNEREOF
{
  "LambdaFunctionConfigurations": [
    {
      "Id": "FaceRecognitionTrigger",
      "LambdaFunctionArn": "$LAMBDA_ARN",
      "Events": ["s3:ObjectCreated:*"]
    }
  ]
}
INNNEREOF

aws s3api put-bucket-notification-configuration --bucket $IN_BUCKET --notification-configuration file://notification.json

rm notification.json lambda_function.zip

echo "=========================================="
echo "✅ Setup erfolgreich abgeschlossen!"
echo "Verwendete Komponenten:"
echo "- In-Bucket:  $IN_BUCKET"
echo "- Out-Bucket: $OUT_BUCKET"
echo "- IAM Role:   LabRole (Standard)"
echo "- Lambda:     $LAMBDA_NAME"
echo "=========================================="