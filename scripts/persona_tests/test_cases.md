# Persona Test Cases

## Scope
- Rails + Inertia web flow sanity
- Existing API route compatibility (read-only check by route build)
- Frontend bundle validity (Vite build)

## Persona Matrix

| Persona | 핵심 시나리오 | 기대 결과 |
|---|---|---|
| Guest Visitor | `GET /` | `302 -> /auth/login` |
| New User Onboarding | `/auth/login -> /auth/verify -> /auth/register` | 각 페이지 Inertia 컴포넌트 렌더링 |
| Active User | 인증 후 홈/브로드캐스트/대화/프로필/설정/알림 접근 | 각 페이지 `200` + 예상 컴포넌트 |
| Admin Auditor | `/admin`, `/admin/reports`, `/admin/users` + 처리/정지/해제 액션 | 화면 렌더링 및 조치 redirect 성공 |

## Automated Specs
- `spec/requests/web/persona_flows_spec.rb`

## Execution
```bash
bash scripts/persona_tests/run_persona_checks.sh
```

## Pass Criteria
1. Persona request spec 전부 PASS
2. `bundle exec rails routes` 성공
3. `npx vite build` 성공
