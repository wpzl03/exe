<!-- capture-farm.ps1 이 farm-orders/index.html 의 </body> 앞에 끼워 넣는 예시 데이터 스크립트 -->
<script>
(function () {
  orders = [];
  const msgs = [
    SAMPLES[0],
    SAMPLES[1],
    "사과 3박스요. 이영희 010-1111-2222 부산 해운대구 해운대로 100",
    "2026년 11월 7일 오후 3:12, 최수정 : 감자 10키로 2상자 보내주세요\n대전 유성구 대학로 99 / 01055556666",
    "정다은 010-3333-4444 광주 서구 상무대로 77 고구마 2박스 부탁드려요",
  ];
  msgs.forEach((m) => {
    document.querySelector("#rawMsg").value = m;
    document.querySelector("#parseBtn").click();
    document.querySelector("#orderForm").requestSubmit();
    document.querySelector("#msgDialog").close();
  });
  const now = new Date().toISOString();
  Object.assign(orders[0], { status: "발송완료", paidAt: now, shippedAt: now, tracking: "5551-2345-6789" });
  Object.assign(orders[1], { status: "입금확인", paidAt: now });
  Object.assign(orders[2], { status: "입금확인", paidAt: now });
  save(); renderAll();

  // 주소 끝의 #list / #input 으로 어떤 화면을 찍을지 정함
  const mode = location.hash.slice(1) || "list";
  if (mode === "input") {
    document.querySelector("#rawMsg").value = SAMPLES[0];
    document.querySelector("#parseBtn").click();
  }
  showTab(mode);
  document.getElementById("toast").classList.remove("show");

  // 문서용 캡처에는 로고(🌾 아이콘)를 넣지 않음
  const h1 = document.querySelector("header.top h1");
  if (h1 && h1.firstChild && h1.firstChild.nodeType === 3) h1.firstChild.textContent = "";
})();
</script>
