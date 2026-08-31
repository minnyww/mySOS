# MySOS 🚨

แอปขอความช่วยเหลือฉุกเฉิน (SOS) สำหรับ **iOS และ Android** — สร้างด้วย **Flutter + Firebase**

ผู้ใช้ (เช่น ผู้สูงอายุ) กดปุ่ม SOS **จากในแอปหรือจาก Widget บนหน้าจอหลัก** แล้วระบบจะแจ้งเตือน **ผู้ดูแลพร้อมกัน 3 ช่องทาง**:

| ช่องทาง | เงื่อนไข | ค่าใช้จ่าย |
|---|---|---|
| 🔔 Push (FCM) | ผู้ดูแลติดตั้งแอป | ฟรี |
| 💬 LINE OA | ผู้ดูแลเพิ่มเพื่อน OA + เชื่อมรหัส | ฟรี (แพ็กเกจ OA ฟรี) |
| 📱 SMS (BoostSMS) | กรอกเบอร์โทรผู้ดูแล + ใส่ API key | เครดิต BoostSMS (ทดลองฟรี 100 ข้อความ) |

พร้อมพิกัด GPS ในแจ้งเตือน (ขอสิทธิ์ตอนกด SOS ครั้งแรก ปฏิเสธได้ แจ้งเตือนยังส่งได้)

## ความปลอดภัยของผู้ใช้

- กดปุ่มแล้วมี **นับถอยหลัง 3 วินาที** ให้ยกเลิกได้ (กันกดพลาด)
- ส่งซ้ำได้ก็จริงแต่ **มี cooldown 60 วินาที** (กันสแปมผู้ดูแล)
- ผู้ดูแลกด "รับทราบ" → ผู้ใช้เห็นทันทีว่ามีคนกำลังมาช่วย
- ผู้ใช้ยกเลิก SOS ได้ แล้วระบบแจ้งผู้ดูแลด้วย

---

## โครงสร้างโปรเจกต์

```
mysos/
├─ lib/                    # แอป Flutter (Dart)
│  ├─ screens/             #   หน้าจอทั้ง 13 หน้า
│  ├─ services/            #   Firebase/FCM/ตำแหน่ง/จับคู่/SOS
│  ├─ state/               #   Riverpod providers
│  └─ widgets/             #   ชิ้นส่วน UI ร่วม
├─ android/                # รวม Widget Android (SosWidgetProvider.kt)
├─ ios/SosWidget/          # รวม Widget iOS (SwiftUI WidgetKit)
├─ functions/              # Cloud Functions (TypeScript)
│  └─ src/
│     ├─ alerts.ts         #   fan-out SOS 3 ช่องทาง + ack/cancel
│     ├─ pairing.ts        #   จับคู่ QR/รหัส
│     ├─ lineWebhook.ts    #   LINE Messaging API webhook
│     ├─ line.ts           #   ส่งข้อความ LINE
│     └─ boostsms.ts       #   ส่ง SMS ผ่าน BoostSMS API
├─ firestore.rules         # Security Rules (เข้มงวด)
└─ firebase.json
```

### ฟลูการทำงาน

**จับคู่ (QR + รหัส 6 หลัก)**
1. ผู้ใช้: หน้าหลัก → "เชื่อมต่อผู้ดูแล" → แสดง **QR + รหัส 6 หลัก** (อายุ 10 นาที)
2. ผู้ดูแล: "จับคู่กับผู้ใช้" → **สแกน QR** ด้วยกล้อง หรือ **กรอกรหัส**
3. กดยืนยัน → Cloud Function เชื่อมสองบัญชี → ทั้งสองฝั่งเห็นยืนยัน

**เชื่อม LINE (ฝั่งผู้ดูแล)**
1. ตั้งค่า → "รับแจ้งเตือนผ่าน LINE" → เพิ่มเพื่อน OA (ปุ่มเปิด LINE ให้)
2. สร้างรหัส 6 หลัก → ส่งรหัสนั้นในแชท OA → webhook เชื่อมบัญชีอัตโนมัติ

**กด SOS**
- ปุ่มในแอป / Widget หน้าจอหลัก → นับถอยหลัง 3 วิ → ส่ง
- Cloud Function กระจาย: FCM (high priority + sound) / LINE (ปุ่มดูแผนที่ + โทร) / SMS
- หน้าจอแสดงสถานะส่งแต่ละช่องทางแบบเรียลไทม์

---

## 🚀 เริ่มต้นการตั้งค่า (ทำครั้งเดียว)

### 1) โปรเจกต์ Firebase

1. สร้างโปรเจกต์ที่ https://console.firebase.google.com (แชร์แผน **Blaze** จำเป็นสำหรับ Cloud Functions ที่เรียก LINE/BoostSMS — มีโควตาฟรีในตัว ไม่มีค่าใช้จ่ายจนกว่าจะเกินโควตา)
2. **Authentication** → Sign-in method → เปิด **Anonymous**
3. **Firestore Database** → สร้าง database (โหมด production)
4. เชื่อมแอป:
   ```bash
   # ติดตั้ง CLI (ถ้ายังไม่มี) แล้วล็อกอิน
   npm i -g firebase-tools && firebase login
   # generate ไฟล์ firebase_options.dart + google-services.json + GoogleService-Info.plist
   flutterfire configure
   ```
5. เลือกโปรเจกต์ + แพลตฟอร์ม android & ios แล้วเช็คว่าได้ไฟล์:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
6. ตั้ง project id:
   ```bash
   firebase use --add
   ```

### 2) Push บน iOS (APNs)

1. Apple Developer → Keys → สร้าง **APNs Auth Key (.p8)**
2. Firebase Console → Project settings → Cloud Messaging → iOS → **อัปโหลดไฟล์ .p8**
3. Xcode → target Runner → Signing & Capabilities → เพิ่ม **Push Notifications** + **Background Modes** (เลือก Remote notifications)

> ⚠️ Simulator iOS **ส่ง push ไม่ได้** — ต้องทดสอบบนเครื่องจริง

### 3) LINE Official Account

1. https://developers.line.biz → สร้าง **Messaging API channel**
2. เปิดใช้ "Use webhook" และปิด "auto-reply messages" (ตัวเดิม)
3. คัดลอก **Channel access token** และ **Channel secret** ไปวางใน `functions/.env`
4. หา URL เพิ่มเพื่อน (`https://line.me/R/ti/p/@xxxx`) มาใส่ที่ `lib/config.dart` → `lineOaUrl`
5. หลัง deploy functions (ข้อ 5) กลับมาตั้ง Webhook URL = ลิงก์ function `lineWebhook`

### 4) BoostSMS (SMS)

1. สมัคร https://app.boost-sms.com/register (เครดิตทดลอง 100 ข้อความ)
2. Dashboard → API → สร้าง **API Key**
3. วางคีย์ใน `functions/.env`
4. หมายเหตุ: SMS ภาษาไทยจำกัด ~70 ตัวอักษรต่อเซกเมนต์ — ข้อความ SOS ของเราสั้นและมีลิงก์แผนที่ (ยาวเกิน 70 จะถูกนับเป็น 2 เซกเมนต์ ตามราคาปกติของผู้ให้บริการ)

> ไม่ใส่คีย์ก็ได้ — ระบบจะข้ามช่องทาง SMS เองโดยไม่พัง

### 5) Environment ของ Functions

```bash
cd functions
cp .env.example .env    # แล้วกรอกค่าจริง
npm install
```

---

## ▶️ รันแอป

```bash
# Android (เครื่องจริง/emulator ที่มี Play Services)
flutter run

# iOS (ต้อง pod install ครั้งแรก)
cd ios && pod install && cd ..
flutter run
```

### โหมดทดสอบกับ Firebase Emulator (ไม่แตะข้อมูลจริง)

```bash
# ปลายทาง 1: รัน emulator
cd functions && npm run serve          # auth+firestore+functions บนพอร์ตมาตรฐาน

# ปลายทาง 2: รันแอปชี้ไปที่ emulator
USE_FIREBASE_EMULATORS=true flutter run
```

### Deploy ระบบหลังบ้าน

```bash
firebase deploy --only functions,firestore:rules,firestore:indexes
# แล้วกลับไปตั้ง Webhook URL ของ LINE OA = ลิงก์ lineWebhook ที่ได้จากผลลัพธ์ deploy
```

### ทดสอบแจ้งเตือน

- **ฝั่งผู้ดูแล**: ตั้งค่า → "ทดสอบเสียง/แจ้งเตือนบนเครื่องนี้"
- **ทดสอบทั้งระบบ**: ผู้ใช้กด SOS จริง (แนะนำสร้างบัญชีผู้ใช้+ผู้ดูแลบนเครื่องทดสอบ 2 เครื่อง/2 อีมูเลเตอร์)

---

## 🧩 Widget หน้าจอหลัก

**Android**: กดค้างหน้าจอหลัก → Widgets → **SOS** (MySOS)
**iOS**: กดค้าง → + → หา **MySOS Widget**

การทำงาน: แตะ Widget → เปิดแอปเข้าสู่โหมดส่งอัตโนมัติทันที (มี 3 วิให้ยกเลิก)
> เป็นข้อจำกัดของ iOS ที่ Widget ส่ง network เองตอนแตะไม่ได้ จึงออกแบบให้เปิดแอปแวบเดียวแล้วส่งเลย

---

## 🔒 หมายเหตุด้านความปลอดภัย

- การเขียน Firestore ทั้งหมดถูกจำกัดด้วย `firestore.rules`:
  - แก้รายชื่อผู้ดูแล/ผู้ใช้ที่เชื่อมกัน ได้เฉพาะจาก Cloud Functions เท่านั้น
  - รหัสจับคู่ใช้ได้ครั้งเดียว หมดอายุ 10 นาที และอีกฝ่ายเขียนได้แค่ uid ของตัวเอง
  - อ่าน alert ได้เฉพาะเจ้าของและผู้ดูแลที่เชื่อมอยู่เท่านั้น
- แจ้งเตือนทุกช่องทางยิงจาก **เซิร์ฟเวอร์เท่านั้น** (client ไม่มี token LINE/BoostSMS)

## 🗄️ โครงสร้างบน Firebase (chayen-2)

- แอปนี้ใช้ **Firestore database ชื่อ `mysosdb`** (region `asia-southeast1`) ไม่ใช่ `(default)`
  เพราะ `(default)` ของโปรเจกต์นี้อยู่ region `asia-southeast3` ซึ่ง Eventarc (ที่ใช้ trigger
  Cloud Functions) ยังไม่รองรับ และเป็นข้อมูลของแอปอื่น (trips) อยู่แล้ว
- Cloud Functions ทุกตัวอยู่ region `asia-southeast1` และ trigger ผูกกับ `mysosdb`
- LINE Webhook URL ที่ต้องตั้งใน LINE Developers Console:
  `https://asia-southeast1-chayen-2.cloudfunctions.net/lineWebhook`
- ตัวแปรแวดล้อม (LINE/BoostSMS keys) อยู่ใน `functions/.env` (ไม่ถูก commit) —
  ตั้งค่าแล้ว deploy ใหม่เสมอ: `firebase deploy --only functions`
- ทดสอบ backend end-to-end ด้วย emulator:
  ```bash
  cd functions && node scripts/emulator-test.mjs   # ต้องรัน emulators อยู่ก่อน
  ```


## 🧪 ทดสอบ

```bash
flutter analyze        # ผ่าน 0 issues
flutter test           # unit + widget tests
cd functions && npm run build   # ตรวจ TypeScript
```

## ถัดไปที่ควรทำ (แนะนำ)

- [ ] เปลี่ยน Anonymous Auth เป็น Phone Auth (บัญชีไม่หายเมื่อลงแอปใหม่)
- [ ] เสียงแจ้งเตือนดังเป็นพิเศษ + Critical Alert (iOS) / full-screen intent (Android 14+)
- [ ] ปุ่มเรียก 1669 ฉุกเฉินทางการแพทย์โดยตรง
- [ ] ตรวจ "ผู้ใช้ไม่ได้ขยับนาน" (check-in รายวัน) แจ้งผู้ดูแลเมื่อไม่มีการตอบ
