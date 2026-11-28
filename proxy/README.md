# AI 카테고리 분류 서버 설정 안내

앱이 키워드 규칙으로 분류하지 못한 품목만 이 작은 서버(Cloudflare Worker)로 보내고,
서버가 Claude(claude-haiku-5-5)에게 물어서 **내가 만든 카테고리 중 하나**를 골라 돌려줍니다.

```
앱  ──(품목 이름, 구매처, 카테고리 이름)──▶  내 Cloudflare Worker  ──(API 키)──▶  Claude
```

- **API 키는 서버에만** 있고 앱에는 들어가지 않습니다.
- 앱 → 서버 요청에는 내가 정한 **앱 비밀번호(APP_TOKEN)** 가 붙어서, 주소를 알아낸 다른 사람은 쓸 수 없습니다.
- 사진과 금액은 보내지 않습니다.
- 서버를 안 만들었거나 인터넷이 안 되면 앱은 지금처럼 키워드 규칙으로만 분류합니다.

비용: Claude Haiku 5.5는 아주 저렴해서 영수증 한 장에 1원도 들지 않습니다. Cloudflare Worker는 무료 요금제(하루 10만 번)로 충분합니다.

<br>

## 1. Anthropic API 키 만들기

1. https://console.anthropic.com 에 가입하고 로그인합니다.
2. 왼쪽 메뉴 **Billing** 에서 결제 수단을 등록하고 크레딧을 충전합니다. (최소 금액 $5 정도면 아주 오래 씁니다)
3. (권장) **Limits** 에서 월 사용 한도를 낮게(예: $5) 정해 두면, 혹시 문제가 생겨도 그 이상 나가지 않습니다.
4. **API Keys** → **Create Key** → 이름은 `budget-app` 처럼 아무거나 → 만들기.
5. `sk-ant-` 로 시작하는 키가 **한 번만** 보입니다. 메모장에 잠깐 붙여 두세요. (다른 사람에게 보여 주거나 깃허브에 올리면 안 됩니다)

<br>

## 2. Cloudflare 가입

https://dash.cloudflare.com/sign-up 에서 무료로 가입하고 이메일 인증까지 마칩니다. 카드는 필요 없습니다.

<br>

## 3. Node.js 설치

https://nodejs.org 에서 **LTS** 버전을 받아 설치합니다. 설치 중 나오는 옵션은 모두 기본값으로 두면 됩니다.

설치가 끝나면 **명령 프롬프트를 새로 열고** 아래를 입력해 버전 숫자가 나오는지 확인합니다.

```
node -v
```

<br>

## 4. 서버 올리기

명령 프롬프트에서 한 줄씩 입력합니다.

```
cd C:\Users\cielo\budget-app-new
git pull
cd proxy
npm install
npx wrangler login
```

`wrangler login` 을 하면 브라우저가 열립니다. Cloudflare에 로그인한 뒤 **Allow** 를 누르고 명령 프롬프트로 돌아옵니다.

이어서 서버를 올립니다.

```
npx wrangler deploy
```

- 처음이면 `workers.dev` 주소에 쓸 이름(서브도메인)을 정하라고 할 수 있어요. 영어로 아무 이름이나 정하면 됩니다.
- 끝나면 `https://budget-ai-proxy.내이름.workers.dev` 같은 **주소**가 나옵니다. 이 주소를 메모해 두세요.

<br>

## 5. 키와 앱 비밀번호 넣기

```
npx wrangler secret put ANTHROPIC_API_KEY
```

`Enter a secret value:` 가 나오면 1번에서 만든 `sk-ant-...` 키를 붙여 넣고 Enter. (붙여 넣어도 화면에 안 보이는 게 정상입니다)

```
npx wrangler secret put APP_TOKEN
```

이번에는 **앱 비밀번호**로 쓸 문자열을 직접 정해서 넣습니다. 영어와 숫자를 섞어 20자 이상으로 길게 정하세요. (예: `gagyebu7Qm2xT9vLw4Rk8z`) 이것도 메모해 두세요.

확인: 브라우저로 4번에서 받은 주소를 열어 `{"ok":true,"configured":true}` 가 보이면 서버 준비 끝입니다.
`"configured":false` 면 5번의 두 값 중 하나가 빠진 거예요.

<br>

## 6. 앱에 연결하기

1. 앱 폴더에서 평소처럼 실행합니다.
   ```
   cd C:\Users\cielo\budget-app-new
   flutter run
   ```
2. 앱 위쪽 바의 **카테고리 관리** → 맨 위 **AI 자동 분류** 를 누릅니다.
3. **서버 주소**에 4번 주소, **앱 비밀번호**에 5번에서 정한 APP_TOKEN을 넣습니다.
4. **연결 확인** 을 눌러 `연결됐어요. "아이스 아메리카노" → 카페/간식` 처럼 나오면 성공. **저장** 을 누릅니다.

이제 영수증을 찍었을 때 키워드로 못 찾은 품목은 잠깐 "AI가 카테고리를 고르고 있어요"가 보인 뒤 카테고리가 채워지고,
그 항목에는 "AI가 골랐어요"라고 표시됩니다. 그대로 저장하면 그 품목 이름을 키워드로 기억해서 다음부터는 AI에 묻지 않고 바로 분류합니다.

AI를 끄고 싶으면 설정 화면에서 두 칸을 비우고 저장하면 됩니다.

<br>

## 문제가 생기면

| 앱에 나오는 말 | 해결 |
|---|---|
| 서버에 연결하지 못했어요 | 주소 오타, 에뮬레이터 인터넷 연결 확인. 브라우저로 주소가 열리는지 확인 |
| 앱 비밀번호가 서버와 달라요 | `npx wrangler secret put APP_TOKEN` 으로 다시 넣고, 앱에도 똑같이 입력 |
| API 키가 올바르지 않아요 | `npx wrangler secret put ANTHROPIC_API_KEY` 로 키를 다시 넣기 |
| 서버 오류가 났어요 | Anthropic 콘솔의 Billing에서 크레딧이 남았는지 확인. `npx wrangler tail` 을 켜 두고 다시 해 보면 오류 내용이 보여요 |

코드를 고친 뒤 서버를 다시 올릴 때는 `proxy` 폴더에서 `npx wrangler deploy` 만 하면 됩니다. (키와 비밀번호는 그대로 남아 있어요)
