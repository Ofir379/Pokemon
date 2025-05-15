#!/bin/bash

# === הגדרות ===
KEY_NAME="pokemon-key"
SECURITY_GROUP="pokemon-sg"
INSTANCE_NAME="pokemon-instance"
REGION="us-west-2"  # אפשר להחליף ל-us-east-1 אם תרצי
AMI_ID="ami-0e34e7b9ca0ace12d"  # Amazon Linux 2 באזור us-west-2
INSTANCE_TYPE="t2.micro"
REPO_URL="https://github.com/Ofir379/Pokemon.git"
USER_DATA_FILE="pokemon-userdata.sh"

# === קבלת VPC ברירת מחדל ===
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" \
          --query "Vpcs[0].VpcId" --output text --region $REGION)

echo "🌐 Using VPC: $VPC_ID"

# === יצירת KEY PAIR אם לא קיים ===
if [ ! -f "${KEY_NAME}.pem" ]; then
    echo "🔑 יוצרים מפתח SSH חדש..."
    aws ec2 create-key-pair --key-name $KEY_NAME \
        --query 'KeyMaterial' --output text \
        --region $REGION > ${KEY_NAME}.pem
    chmod 400 ${KEY_NAME}.pem
else
    echo "🔑 מפתח SSH כבר קיים: ${KEY_NAME}.pem"
fi

# === בדיקה או יצירה של SECURITY GROUP ===
SG_ID=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=$SECURITY_GROUP Name=vpc-id,Values=$VPC_ID \
    --region $REGION \
    --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
  echo "🛡️ יוצרים קבוצת אבטחה חדשה..."
  SG_ID=$(aws ec2 create-security-group \
      --group-name $SECURITY_GROUP \
      --description "Security group for Pokemon project" \
      --vpc-id $VPC_ID \
      --region $REGION \
      --query 'GroupId' --output text)

  # פתיחת פורט 22 ל־SSH
  aws ec2 authorize-security-group-ingress \
      --group-id $SG_ID \
      --protocol tcp --port 22 \
      --cidr 0.0.0.0/0 \
      --region $REGION
else
  echo "🛡️ קבוצת האבטחה כבר קיימת: $SG_ID"
fi

# === יצירת קובץ user-data ===
cat > $USER_DATA_FILE <<EOF
#!/bin/bash
yum update -y
yum install -y git python3
cd /home/ec2-user
git clone $REPO_URL
echo "To run the app, type: python3 Pokemon/pokemon.py" >> /etc/motd
EOF

# === יצירת אינסטנס EC2 ===
echo "🚀 מקימים את השרת..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --user-data file://$USER_DATA_FILE \
    --region $REGION \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --query 'Instances[0].InstanceId' --output text)

# מחכים שהשרת יעלה
echo "⏳ מחכים שהשרת יעלה..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

# === קבלת כתובת IP ===
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $REGION \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "✅ השרת מוכן! כתובת ה-IP: $PUBLIC_IP"
echo "🔐 התחברות: ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
echo "📘 ברגע שתיכנס תראה הסבר שימוש. כדי להריץ את האפליקציה:"
echo "    python3 Pokemon/pokemon.py"


