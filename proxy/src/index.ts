/**
 * 가계부 앱의 AI 카테고리 분류 중계 서버 (Cloudflare Worker).
 *
 * 앱이 키워드 규칙으로 분류하지 못한 품목만 이곳으로 보내면,
 * Claude가 사용자의 카테고리 중 하나를 골라 돌려준다.
 * Anthropic API 키는 이 서버에만 있고 앱에는 들어가지 않는다.
 *
 * 요청:  POST /classify
 *        Authorization: Bearer <APP_TOKEN>
 *        { "categories": ["식비", ...], "items": [{ "name": "...", "merchant": "..." }] }
 * 응답:  { "results": ["식비", null, ...] }   // items와 같은 순서, 모르면 null
 */
import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { z } from "zod";

export interface Env {
  ANTHROPIC_API_KEY: string;
  /** 앱 설정 화면에 넣는 비밀번호. 주소를 알아낸 다른 사람이 키를 쓰지 못하게 막는다. */
  APP_TOKEN: string;
}

const MODEL = "claude-haiku-5-5";
const MAX_ITEMS = 30;
const MAX_CATEGORIES = 50;
const MAX_TEXT = 100;
const UNKNOWN = "모름";

const RequestSchema = z.object({
  categories: z.array(z.string().trim().min(1).max(MAX_TEXT)).min(1).max(MAX_CATEGORIES),
  items: z
    .array(
      z.object({
        name: z.string().trim().min(1).max(MAX_TEXT),
        merchant: z.string().trim().max(MAX_TEXT).nullish(),
      }),
    )
    .min(1)
    .max(MAX_ITEMS),
});

const SYSTEM_PROMPT = `너는 한국어 가계부 앱의 지출 분류기다.
영수증이나 쇼핑앱 결제 화면에서 읽은 품목마다, 사용자가 만든 카테고리 목록 중 가장 알맞은 것을 하나 고른다.
- 품목명이 우선이고, 구매처(가게 이름)는 참고만 한다.
- 품목명이 글자 인식 오류로 조금 깨져 있을 수 있으니 뜻을 짐작해서 고른다.
- 어느 카테고리에도 맞지 않거나 무엇인지 알 수 없으면 "${UNKNOWN}"를 고른다. 억지로 고르지 않는다.
- 결과는 품목 번호(index)마다 하나씩 낸다.`;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // 브라우저로 주소를 열어 보면 살아 있는지 확인할 수 있게
    if (request.method === "GET" && url.pathname === "/") {
      return json({ ok: true, configured: Boolean(env.ANTHROPIC_API_KEY && env.APP_TOKEN) });
    }
    if (request.method !== "POST" || url.pathname !== "/classify") {
      return json({ error: "not_found" }, 404);
    }
    if (!env.ANTHROPIC_API_KEY || !env.APP_TOKEN) {
      return json({ error: "server_not_configured" }, 500);
    }
    if (request.headers.get("authorization") !== `Bearer ${env.APP_TOKEN}`) {
      return json({ error: "wrong_token" }, 401);
    }

    let body;
    try {
      body = RequestSchema.parse(await request.json());
    } catch {
      return json({ error: "bad_request" }, 400);
    }
    const categories = [...new Set(body.categories)];
    const { items } = body;

    const Output = z.object({
      results: z.array(
        z.object({
          index: z.number().int(),
          category: z.enum([UNKNOWN, ...categories]),
        }),
      ),
    });

    const list = items
      .map((it, i) => `${i}. ${it.name}${it.merchant ? ` (구매처: ${it.merchant})` : ""}`)
      .join("\n");

    const client = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY, maxRetries: 1, timeout: 20_000 });
    try {
      const response = await client.messages.parse({
        model: MODEL,
        max_tokens: 2048,
        thinking: { type: "disabled" },
        output_config: { effort: "low", format: zodOutputFormat(Output) },
        system: SYSTEM_PROMPT,
        messages: [
          {
            role: "user",
            content: `카테고리 목록: ${categories.join(", ")}\n\n품목:\n${list}`,
          },
        ],
      });

      if (response.stop_reason === "refusal" || !response.parsed_output) {
        return json({ results: items.map(() => null) });
      }
      const results: (string | null)[] = items.map(() => null);
      for (const r of response.parsed_output.results) {
        if (r.index >= 0 && r.index < items.length && r.category !== UNKNOWN) {
          results[r.index] = r.category;
        }
      }
      return json({ results });
    } catch (e) {
      if (e instanceof Anthropic.AuthenticationError) {
        return json({ error: "bad_api_key" }, 502);
      }
      if (e instanceof Anthropic.RateLimitError) {
        return json({ error: "rate_limited" }, 503);
      }
      if (e instanceof Anthropic.APIError) {
        console.error("Anthropic API error", e.status, e.message);
        return json({ error: "upstream_error" }, 502);
      }
      console.error(e);
      return json({ error: "internal_error" }, 500);
    }
  },
} satisfies ExportedHandler<Env>;
