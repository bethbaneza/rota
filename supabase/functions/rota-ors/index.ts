// Banheza Rota — ponte com o OpenRouteService (distâncias e trajeto pelas ruas).
// A chave do serviço fica só aqui, no servidor (Secret ORS_API_KEY) — nunca no navegador.
//
// Deploy: Supabase -> Edge Functions -> Deploy new function -> nome "rota-ors" -> colar este código.
//   "Verify JWT" LIGADO (padrão): só quem está logado no app chama esta função.
// Secret (Edge Functions -> Secrets):  ORS_API_KEY = a chave do OpenRouteService.
//
// Duas ações (corpo JSON):
//   { "tipo": "matriz", "locais": [[lng,lat], ...] }  -> tempos (s) e distâncias (m) entre todos os pontos
//   { "tipo": "rota",   "locais": [[lng,lat], ...] }  -> traçado pelas ruas, na ordem dada

const KEY = Deno.env.get("ORS_API_KEY") ?? "";
const ORS = "https://api.openrouteservice.org";
const MAX_LOCAIS = 30;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const resp = (body: unknown) =>
  new Response(JSON.stringify(body), { status: 200, headers: { "content-type": "application/json", ...CORS } });

function locaisValidos(l: unknown): l is number[][] {
  if (!Array.isArray(l) || l.length < 2 || l.length > MAX_LOCAIS) return false;
  return l.every((p) =>
    Array.isArray(p) && p.length === 2 && typeof p[0] === "number" && typeof p[1] === "number" &&
    p[0] > -75 && p[0] < -30 && p[1] > -35 && p[1] < 6 // só pontos dentro do Brasil
  );
}

async function chamarORS(caminho: string, corpo: unknown) {
  const r = await fetch(ORS + caminho, {
    method: "POST",
    headers: { Authorization: KEY, "Content-Type": "application/json", Accept: "application/json, application/geo+json" },
    body: JSON.stringify(corpo),
  });
  const txt = await r.text();
  let json: any = null;
  try { json = JSON.parse(txt); } catch { /* resposta não era JSON */ }
  return { ok: r.ok, status: r.status, json, txt };
}

function msgErro(status: number): string {
  if (status === 401 || status === 403) return "A chave do OpenRouteService foi recusada. Confira o Secret ORS_API_KEY.";
  if (status === 429) return "Limite diário gratuito do OpenRouteService atingido. Tente de novo amanhã.";
  if (status === 404 || status === 400) return "Não foi possível traçar a rota entre esses pontos pelas ruas.";
  return "O serviço de rotas não respondeu (erro " + status + ").";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    if (!KEY) return resp({ ok: false, msg: "Chave do OpenRouteService não configurada (Secret ORS_API_KEY)." });
    const b = await req.json().catch(() => ({}));
    if (!locaisValidos(b?.locais)) return resp({ ok: false, msg: "Pontos inválidos." });

    if (b.tipo === "matriz") {
      const r = await chamarORS("/v2/matrix/driving-car", { locations: b.locais, metrics: ["duration", "distance"] });
      if (!r.ok || !r.json?.durations) { console.error("ors matriz", r.status, r.txt.slice(0, 300)); return resp({ ok: false, msg: msgErro(r.status) }); }
      return resp({ ok: true, duracoes: r.json.durations, distancias: r.json.distances });
    }
    if (b.tipo === "rota") {
      const r = await chamarORS("/v2/directions/driving-car/geojson", { coordinates: b.locais, instructions: false });
      const f = r.json?.features?.[0];
      if (!r.ok || !f) { console.error("ors rota", r.status, r.txt.slice(0, 300)); return resp({ ok: false, msg: msgErro(r.status) }); }
      return resp({ ok: true, geometria: f.geometry, resumo: f.properties?.summary ?? null });
    }
    return resp({ ok: false, msg: "Ação desconhecida." });
  } catch (e) {
    console.error("rota-ors falhou:", e);
    return resp({ ok: false, msg: "Erro interno." });
  }
});
