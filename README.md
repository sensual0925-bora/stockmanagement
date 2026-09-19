# 스토어 재고장

스마트스토어 상품의 재고(옵션별 재고 포함)를 핸드폰·컴퓨터에서 관리하는 페이지입니다.

- 사이트: https://sensual0925-bora.github.io/stockmanagement/
- 재고 데이터: Supabase `stock_ledger` 테이블 (저장할 때마다 직전 상태가 `stock_history`에 최근 300개까지 남습니다)
- 처음 설정: `supabase/stock.sql`을 Supabase SQL Editor에서 실행 → Authentication → Users에서 계정 만들기(Auto Confirm) → 그 이메일이 `stock_editors`에 있는지 확인
- 재고를 고치려면 기기마다 한 번 로그인합니다. 보기는 누구나 가능합니다.
- `data/stock.json`은 Supabase로 옮기기 전의 재고입니다. Supabase가 비어 있으면 이 파일을 보여 주고, 편집자가 처음 로그인할 때 자동으로 옮겨 담습니다.
