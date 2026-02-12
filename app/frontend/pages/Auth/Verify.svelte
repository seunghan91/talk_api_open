<script>
  import { router } from "@inertiajs/svelte";
  import Button from "$components/common/Button.svelte";

  let { phone_number = "" } = $props();

  let code = $state("");
  let loading = $state(false);
  let resending = $state(false);
  let errors = $state({});
  let inputs = $state([]);
  const CODE_LENGTH = 6;

  // 6자리 입력 필드 참조
  function handleInput(index, e) {
    const value = e.target.value.replace(/\D/g, "");
    const chars = code.split("");
    chars[index] = value.slice(-1);
    code = chars.join("");

    // 다음 필드로 자동 포커스
    if (value && index < CODE_LENGTH - 1) {
      const next = e.target.parentElement.children[index + 1];
      next?.focus();
    }
  }

  function handleKeydown(index, e) {
    if (e.key === "Backspace" && !code[index] && index > 0) {
      const prev = e.target.parentElement.children[index - 1];
      prev?.focus();
    }
  }

  function handlePaste(e) {
    const text = e.clipboardData.getData("text").replace(/\D/g, "");
    code = text.slice(0, CODE_LENGTH);
    e.preventDefault();
  }

  function handleSubmit(e) {
    e.preventDefault();

    if (code.length !== CODE_LENGTH) {
      errors = { code: "인증번호 6자리를 입력해주세요." };
      return;
    }

    loading = true;
    errors = {};

    router.post("/auth/verify", { code }, {
      onFinish: () => { loading = false; },
      onError: (err) => { errors = err; },
    });
  }

  function handleResend() {
    resending = true;
    router.post("/auth/resend", {}, {
      onFinish: () => { resending = false; },
    });
  }
</script>

<div class="flex min-h-screen items-center justify-center bg-gradient-to-br from-sky-50 via-white to-cyan-50 px-4">
  <div class="w-full max-w-sm">
    <!-- 헤더 -->
    <div class="mb-8 text-center">
      <a href="/auth/login" class="mb-4 inline-block text-sm text-slate-500 hover:text-sky-600">← 뒤로</a>
      <h1 class="text-2xl font-bold text-slate-900">인증번호 입력</h1>
      <p class="mt-2 text-sm text-slate-500">
        <span class="font-medium text-sky-600">{phone_number}</span>으로<br/>
        전송된 6자리 인증번호를 입력해주세요
      </p>
    </div>

    <!-- 인증번호 입력 -->
    <form onsubmit={handleSubmit} class="space-y-6">
      <div class="flex justify-center gap-2" onpaste={handlePaste}>
        {#each Array(CODE_LENGTH) as _, i}
          <input
            type="text"
            inputmode="numeric"
            maxlength="1"
            value={code[i] || ""}
            oninput={(e) => handleInput(i, e)}
            onkeydown={(e) => handleKeydown(i, e)}
            class="h-14 w-12 rounded-xl border border-slate-200 bg-white text-center text-xl font-bold text-slate-900 outline-none transition-colors focus:border-sky-400 focus:ring-2 focus:ring-sky-100"
          />
        {/each}
      </div>

      {#if errors.code}
        <p class="text-center text-xs text-rose-500">{errors.code}</p>
      {/if}

      <Button type="submit" variant="primary" size="xl" {loading} class="w-full">
        {loading ? "확인 중..." : "인증 확인"}
      </Button>

      <div class="text-center">
        <button
          type="button"
          onclick={handleResend}
          disabled={resending}
          class="text-sm text-slate-500 hover:text-sky-600 disabled:opacity-50"
        >
          {resending ? "재전송 중..." : "인증번호 재전송"}
        </button>
      </div>
    </form>
  </div>
</div>
