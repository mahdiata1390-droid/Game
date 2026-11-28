// The council: the campaign screen.
//
// A full-screen war room over the sandbox — world map, ledgers, army, diplomacy,
// heraldry, chronicle and codex. It is built from the same data the world is,
// so a holding you can see on the map is a settlement you can walk through, and
// taking it in the council changes whose banners hang over it.

import { COAST_X, MAP_HALF, ROADS, SITE_BY_ID, type SiteKind } from "../game/geography";
import {
  BUILDINGS,
  SEASONS,
  TROOPS,
  TROOP_ORDER,
  type BuildKind,
  type Kingdom,
  type PowerId,
  type TroopId,
} from "../game/kingdom";
import { CHAMPIONS, HOUSES, WEAPON_PROFILE, houseOf, type House, type HouseId } from "../game/houses";
import { ATLAS_TILE } from "../engine/textures";
import type { SfxId } from "../engine/audio";

/** Painted portraits for the powers that have one; the rest read from their crest. */
const CHAMPION_PORTRAIT: Partial<Record<string, string>> = {
  free_company: "art/champion-company.jpg",
  north_kingdom: "art/champion-north.jpg",
  river_kingdom: "art/champion-river.jpg",
};

type TabId = "realm" | "ledger" | "army" | "diplomacy" | "champions" | "heraldry" | "chronicle" | "codex";

const TABS: Array<{ id: TabId; label: string; glyph: string }> = [
  { id: "realm", label: "World Map", glyph: "◈" },
  { id: "ledger", label: "Kingdom", glyph: "☰" },
  { id: "army", label: "Army", glyph: "⚔" },
  { id: "diplomacy", label: "Diplomacy", glyph: "❖" },
  { id: "champions", label: "Champions", glyph: "♛" },
  { id: "heraldry", label: "Heraldry", glyph: "⛨" },
  { id: "chronicle", label: "Chronicle", glyph: "✒" },
  { id: "codex", label: "Codex", glyph: "✦" },
];

function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  className?: string,
  text?: string,
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function rgb(color: [number, number, number]): string {
  const clamp = (v: number) => Math.round(Math.max(0, Math.min(1, v)) * 255);
  return `rgb(${clamp(color[0])},${clamp(color[1])},${clamp(color[2])})`;
}

function crestSvg(house: House, size: number): SVGSVGElement {
  const ns = "http://www.w3.org/2000/svg";
  const svg = document.createElementNS(ns, "svg");
  svg.setAttribute("viewBox", "0 0 40 46");
  svg.setAttribute("width", String(size));
  svg.setAttribute("height", String(size * 1.15));
  svg.classList.add("crest");

  const plate = document.createElementNS(ns, "path");
  const shieldPath =
    house.shield === "round"
      ? "M20 3 A17 17 0 1 1 19.9 3 Z"
      : house.shield === "kite"
        ? "M20 3 L36 10 V23 Q36 34 20 42 Q4 34 4 23 V10 Z"
        : "M3 4 H37 V22 Q37 33 20 41 Q3 33 3 22 Z";
  plate.setAttribute("d", shieldPath);
  plate.setAttribute("fill", rgb(house.banner));
  plate.setAttribute("stroke", rgb(house.trim));
  plate.setAttribute("stroke-width", "1.6");
  svg.append(plate);

  const ink = document.createElementNS(ns, "g");
  ink.setAttribute("fill", rgb(house.trim));
  ink.setAttribute("stroke", rgb(house.trim));
  ink.setAttribute("stroke-width", "1.4");
  const charge = house.crest;
  if (charge === "tower") {
    const keep = document.createElementNS(ns, "path");
    keep.setAttribute("d", "M14 32 V17 H17 V20 H20 V17 H23 V20 H26 V17 H29 V32 Z");
    ink.append(keep);
  } else if (charge === "sun") {
    const disc = document.createElementNS(ns, "circle");
    disc.setAttribute("cx", "20");
    disc.setAttribute("cy", "22");
    disc.setAttribute("r", "6");
    ink.append(disc);
    for (let i = 0; i < 8; i++) {
      const ray = document.createElementNS(ns, "line");
      const a = (i / 8) * Math.PI * 2;
      ray.setAttribute("x1", String(20 + Math.cos(a) * 8));
      ray.setAttribute("y1", String(22 + Math.sin(a) * 8));
      ray.setAttribute("x2", String(20 + Math.cos(a) * 12));
      ray.setAttribute("y2", String(22 + Math.sin(a) * 12));
      ray.setAttribute("stroke-width", "2");
      ink.append(ray);
    }
  } else if (charge === "crescent") {
    const crescent = document.createElementNS(ns, "path");
    crescent.setAttribute("d", "M26 12 A11 11 0 1 0 26 32 A9 9 0 1 1 26 12 Z");
    ink.append(crescent);
  } else if (charge === "wolf") {
    const head = document.createElementNS(ns, "path");
    head.setAttribute("d", "M11 14 L16 20 L14 32 L20 28 L26 32 L24 20 L29 14 L23 17 L20 13 L17 17 Z");
    ink.append(head);
  } else if (charge === "saltire") {
    for (const d of ["M8 9 L32 36", "M32 9 L8 36"]) {
      const line = document.createElementNS(ns, "path");
      line.setAttribute("d", d);
      line.setAttribute("stroke-width", "4");
      ink.append(line);
    }
  } else {
    const gem = document.createElementNS(ns, "path");
    gem.setAttribute("d", "M20 9 L30 22 L20 35 L10 22 Z");
    ink.append(gem);
  }
  svg.append(ink);
  return svg;
}

function bar(value: number, max: number, className: string): HTMLElement {
  const wrap = el("div", "cbar");
  const fill = el("span", className);
  fill.style.width = `${Math.max(0, Math.min(100, (value / max) * 100))}%`;
  wrap.append(fill);
  return wrap;
}

const KIND_ICON: Record<SiteKind, string> = {
  village: "⌂",
  town: "⛫",
  castle: "♜",
  city: "⛩",
};

export type CouncilOptions = {
  kingdom: Kingdom;
  /** the settlement the map should start on, if any */
  focus?: string;
  onChange?: (message: string, ok: boolean) => void;
  /** advance the calendar one day; the council re-renders afterwards */
  onEndDay?: () => void;
  /** play one of the packaged sounds, if the host has audio */
  onSfx?: (id: SfxId) => void;
};

export class Council {
  private root: HTMLDivElement;
  private tabsEl: HTMLDivElement;
  private bodyEl: HTMLDivElement;
  private headStats: HTMLDivElement;
  private noticeEl: HTMLDivElement;
  private tab: TabId = "realm";
  private selected: string;
  readonly kingdom: Kingdom;
  private onChange: (message: string, ok: boolean) => void;
  private onEndDay?: () => void;
  private onSfx: (id: SfxId) => void;
  open = false;

  constructor(options: CouncilOptions) {
    this.kingdom = options.kingdom;
    this.selected = options.focus ?? this.kingdom.playerHoldings[0]?.id ?? "kingsbridge";
    this.onChange = options.onChange ?? (() => {});
    this.onEndDay = options.onEndDay;
    this.onSfx = options.onSfx ?? (() => {});

    this.root = el("div", "council");
    this.root.setAttribute("aria-hidden", "true");

    const frame = el("div", "council-frame");

    const header = el("header", "council-head");
    const title = el("div", "council-title");
    const crown = el("span", "council-crown", "♔");
    const words = el("div", "council-words");
    const heading = el("h1", undefined, "The Council of the Basin");
    const sub = el("p", undefined, "Medieval Sandbox · campaign of the five powers");
    words.append(heading, sub);
    title.append(crown, words);
    this.headStats = el("div", "council-stats");
    const endDay = el("button", "council-day", "End the day ▸");
    endDay.type = "button";
    endDay.title = "Advance the calendar: taxes, harvests, marches and sieges all move.";
    endDay.addEventListener("click", () => {
      this.onSfx("bell");
      this.onEndDay?.();
      this.render();
    });
    const close = el("button", "council-close", "✕");
    close.type = "button";
    close.setAttribute("aria-label", "Close the council");
    close.addEventListener("click", () => this.close());
    header.append(title, this.headStats, endDay, close);

    this.tabsEl = el("div", "council-tabs");
    for (const tab of TABS) {
      const button = el("button", "council-tab");
      button.type = "button";
      button.dataset.tab = tab.id;
      const glyph = el("span", "tab-glyph", tab.glyph);
      const label = el("span", "tab-label", tab.label);
      button.append(glyph, label);
      button.addEventListener("click", () => {
        this.onSfx("page");
        this.tab = tab.id;
        this.render();
      });
      this.tabsEl.append(button);
    }

    this.bodyEl = el("div", "council-body");
    this.noticeEl = el("div", "council-notice");

    frame.append(header, this.tabsEl, this.bodyEl, this.noticeEl);
    this.root.append(frame);
    this.root.addEventListener("keydown", (event) => {
      if (event.key === "Escape") this.close();
    });
    document.body.append(this.root);
  }

  show(): void {
    this.open = true;
    this.root.classList.add("open");
    this.root.setAttribute("aria-hidden", "false");
    this.render();
  }

  hide(): void {
    this.open = false;
    this.root.classList.remove("open");
    this.root.setAttribute("aria-hidden", "true");
  }

  close(): void {
    this.hide();
    this.onChange("", true);
  }

  destroy(): void {
    this.hide();
    this.root.remove();
  }

  refresh(): void {
    if (this.open) this.render();
  }

  // ------------------------------------------------------------------ render

  private render(): void {
    const k = this.kingdom;
    const power = k.playerPower;
    const income = k.incomeOf(k.player);
    const upkeep = k.upkeepOf(k.player);

    this.headStats.replaceChildren(
      this.stat("Day", `${k.day}`, `${SEASONS[Math.floor(((k.day - 1) % 96) / 24)]}`),
      this.stat("Treasury", `${Math.round(power.gold)}`, `${income.gold - upkeep >= 0 ? "+" : ""}${income.gold - upkeep}/day`),
      this.stat("Granary", `${Math.round(power.food)}`, `${income.food}/day`),
      this.stat("Renown", `${Math.round(power.renown)}`, `#${k.standings.findIndex((row) => row.id === k.player) + 1} of 6`),
    );

    for (const button of Array.from(this.tabsEl.children)) {
      const element = button as HTMLButtonElement;
      element.classList.toggle("active", element.dataset.tab === this.tab);
    }

    this.bodyEl.replaceChildren();
    switch (this.tab) {
      case "realm": this.renderRealm(); break;
      case "ledger": this.renderLedger(); break;
      case "army": this.renderArmy(); break;
      case "diplomacy": this.renderDiplomacy(); break;
      case "champions": this.renderChampions(); break;
      case "heraldry": this.renderHeraldry(); break;
      case "chronicle": this.renderChronicle(); break;
      case "codex": this.renderCodex(); break;
    }
    this.noticeEl.textContent = k.notice;
  }

  private stat(label: string, value: string, note: string): HTMLElement {
    const box = el("div", "cstat");
    box.append(
      el("span", "cstat-label", label),
      el("strong", "cstat-value", value),
      el("span", "cstat-note", note),
    );
    return box;
  }

  private act(ok: boolean, message: string): void {
    this.onChange(message, ok);
    this.render();
  }

  // ---------------------------------------------------------------- the realm

  private renderRealm(): void {
    const k = this.kingdom;
    const layout = el("div", "realm-layout");

    const mapWrap = el("div", "realm-map");
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("viewBox", "0 0 100 100");
    svg.classList.add("realm-svg");

    const sea = document.createElementNS("http://www.w3.org/2000/svg", "rect");
    const seaLeft = ((COAST_X + MAP_HALF) / (MAP_HALF * 2)) * 100;
    sea.setAttribute("x", String(seaLeft));
    sea.setAttribute("y", "0");
    sea.setAttribute("width", String(100 - seaLeft));
    sea.setAttribute("height", "100");
    sea.setAttribute("fill", "#123441");
    sea.setAttribute("opacity", "0.9");
    svg.append(sea);

    const shore = document.createElementNS("http://www.w3.org/2000/svg", "line");
    shore.setAttribute("x1", String(seaLeft));
    shore.setAttribute("y1", "0");
    shore.setAttribute("x2", String(seaLeft));
    shore.setAttribute("y2", "100");
    shore.setAttribute("stroke", "#c9b489");
    shore.setAttribute("stroke-opacity", "0.5");
    shore.setAttribute("stroke-width", "0.6");
    svg.append(shore);

    for (let i = 0; i < 9; i++) {
      const wave = document.createElementNS("http://www.w3.org/2000/svg", "path");
      const y = 6 + i * 11;
      wave.setAttribute("d", `M${seaLeft + 3} ${y} q 4 -2 8 0 t 8 0 t 8 0`);
      wave.setAttribute("stroke", "#35707f");
      wave.setAttribute("stroke-width", "0.35");
      wave.setAttribute("fill", "none");
      wave.setAttribute("opacity", "0.45");
      svg.append(wave);
    }

    for (const house of Object.values(HOUSES)) {
      const sites = k.holdings.filter((holding) => holding.owner === house.id);
      if (sites.length === 0) continue;
      const cx = sites.reduce((sum, site) => sum + site.x, 0) / sites.length;
      const cz = sites.reduce((sum, site) => sum + site.z, 0) / sites.length;
      const spread = Math.max(
        26,
        Math.max(...sites.map((site) => Math.hypot(site.x - cx, site.z - cz))) * 0.82,
      );
      const blob = document.createElementNS("http://www.w3.org/2000/svg", "circle");
      blob.setAttribute("cx", String(((cx + MAP_HALF) / (MAP_HALF * 2)) * 100));
      blob.setAttribute("cy", String(((cz + MAP_HALF) / (MAP_HALF * 2)) * 100));
      blob.setAttribute("r", String((spread / (MAP_HALF * 2)) * 100));
      blob.setAttribute("fill", rgb(house.banner));
      blob.setAttribute("fill-opacity", house.id === k.player ? "0.28" : "0.16");
      blob.setAttribute("stroke", rgb(house.trim));
      blob.setAttribute("stroke-opacity", "0.45");
      blob.setAttribute("stroke-width", "0.35");
      blob.setAttribute("stroke-dasharray", "1.4 1.2");
      svg.append(blob);
    }

    const project = (x: number, z: number) => ({
      cx: ((x + MAP_HALF) / (MAP_HALF * 2)) * 100,
      cy: ((z + MAP_HALF) / (MAP_HALF * 2)) * 100,
    });

    for (const [a, b] of ROADS) {
      const from = SITE_BY_ID[a];
      const to = SITE_BY_ID[b];
      if (!from || !to) continue;
      const p1 = project(from.x, from.z);
      const p2 = project(to.x, to.z);
      const road = document.createElementNS("http://www.w3.org/2000/svg", "line");
      road.setAttribute("x1", String(p1.cx));
      road.setAttribute("y1", String(p1.cy));
      road.setAttribute("x2", String(p2.cx));
      road.setAttribute("y2", String(p2.cy));
      road.setAttribute("stroke", "#c9b489");
      road.setAttribute("stroke-opacity", "0.28");
      road.setAttribute("stroke-width", "0.5");
      road.setAttribute("stroke-dasharray", "1 0.8");
      svg.append(road);
    }

    const radius: Record<SiteKind, number> = { village: 0.9, town: 1.15, castle: 1.35, city: 1.7 };
    for (const holding of k.holdings) {
      const house = houseOf(holding.owner);
      const p = project(holding.x, holding.z);
      const group = document.createElementNS("http://www.w3.org/2000/svg", "g");
      group.classList.add("realm-site");
      group.dataset.site = holding.id;
      if (holding.id === this.selected) group.classList.add("selected");

      if (holding.siege) {
        const ring = document.createElementNS("http://www.w3.org/2000/svg", "circle");
        ring.setAttribute("cx", String(p.cx));
        ring.setAttribute("cy", String(p.cy));
        ring.setAttribute("r", String(radius[holding.kind] + 1.2));
        ring.setAttribute("fill", "none");
        ring.setAttribute("stroke", "#e0563a");
        ring.setAttribute("stroke-width", "0.45");
        ring.setAttribute("stroke-dasharray", "1 0.9");
        group.append(ring);
      }

      const dot = document.createElementNS("http://www.w3.org/2000/svg", "circle");
      dot.setAttribute("cx", String(p.cx));
      dot.setAttribute("cy", String(p.cy));
      dot.setAttribute("r", String(radius[holding.kind]));
      dot.setAttribute("fill", rgb(house.banner));
      dot.setAttribute("stroke", holding.id === this.selected ? "#f4dfa4" : "#101319");
      dot.setAttribute("stroke-width", holding.id === this.selected ? "0.55" : "0.3");
      group.append(dot);

      if (holding.port) {
        const anchor = document.createElementNS("http://www.w3.org/2000/svg", "path");
        anchor.setAttribute("d", `M${p.cx - 0.7} ${p.cy + 1.9} h1.4 M${p.cx} ${p.cy + 1.4} v1.1`);
        anchor.setAttribute("stroke", "#cfe6ee");
        anchor.setAttribute("stroke-width", "0.22");
        group.append(anchor);
      }

      if (holding.kind === "city" || holding.kind === "castle") {
        const label = document.createElementNS("http://www.w3.org/2000/svg", "text");
        label.setAttribute("x", String(p.cx));
        label.setAttribute("y", String(p.cy - radius[holding.kind] - 0.6));
        label.setAttribute("text-anchor", "middle");
        label.setAttribute("font-size", "1.85");
        label.setAttribute("fill", "#efe4c8");
        label.setAttribute("opacity", "0.82");
        label.textContent = holding.name;
        group.append(label);
      }

      group.addEventListener("click", () => {
        this.onSfx("page");
        this.selected = holding.id;
        this.render();
      });
      svg.append(group);
    }

    const here = project(0, 14);
    const player = document.createElementNS("http://www.w3.org/2000/svg", "g");
    const ping = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    ping.setAttribute("cx", String(here.cx));
    ping.setAttribute("cy", String(here.cy));
    ping.setAttribute("r", "2.4");
    ping.setAttribute("fill", "none");
    ping.setAttribute("stroke", "#f4dfa4");
    ping.setAttribute("stroke-width", "0.4");
    const you = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    you.setAttribute("cx", String(here.cx));
    you.setAttribute("cy", String(here.cy));
    you.setAttribute("r", "0.9");
    you.setAttribute("fill", "#f4dfa4");
    player.append(ping, you);
    svg.append(player);

    mapWrap.append(svg);

    const legend = el("div", "realm-legend");
    for (const house of Object.values(HOUSES)) {
      const owned = k.holdings.filter((holding) => holding.owner === house.id).length;
      if (owned === 0) continue;
      const item = el("span", "legend-item");
      const swatch = el("i", "legend-swatch");
      swatch.style.background = rgb(house.banner);
      item.append(swatch, document.createTextNode(`${house.name} · ${owned}`));
      legend.append(item);
    }
    mapWrap.append(legend);

    const detail = el("div", "realm-detail");
    const holding = k.holding(this.selected);
    if (!holding) {
      detail.append(el("p", "muted", "Select a holding on the map."));
    } else {
      const house = houseOf(holding.owner);
      const head = el("div", "detail-head");
      const shield = crestSvg(house, 34);
      const names = el("div", "detail-names");
      names.append(
        el("h2", undefined, holding.name),
        el("p", "muted", `${house.name} · ${holding.kind[0].toUpperCase()}${holding.kind.slice(1)}${holding.port ? " · port" : ""}`),
      );
      head.append(shield, names);
      detail.append(head);

      const facts = el("div", "detail-facts");
      const fact = (label: string, value: string) => {
        const row = el("div", "fact");
        row.append(el("span", "fact-label", label), el("strong", undefined, value));
        facts.append(row);
      };
      fact("Population", holding.population.toLocaleString());
      fact("Garrison", `${holding.garrison}`);
      fact("Walls", `${holding.walls > 0 ? `tier ${holding.walls}` : "palisade only"}`);
      fact("Market", `${holding.market > 0 ? `tier ${holding.market}` : "none"}`);
      fact("Fields", `tier ${holding.farms}`);
      fact("Produce", holding.resource);
      detail.append(facts);

      const unrestLabel = el("div", "meter-label");
      unrestLabel.append(el("span", undefined, "Unrest"), el("span", undefined, `${Math.round(holding.unrest)} / 100`));
      detail.append(unrestLabel, bar(holding.unrest, 100, "cbar-fill danger"));

      if (holding.siege) {
        const siege = el("div", "siege");
        siege.append(
          el("strong", undefined, `Under siege by ${HOUSES[holding.siege.by].name}`),
          bar(holding.siege.progress, 100, "cbar-fill danger"),
        );
        detail.append(siege);
      }

      if (holding.owner === k.player) {
        detail.append(el("h3", "detail-sub", "Build"));
        const buildRow = el("div", "action-grid");
        (Object.keys(BUILDINGS) as BuildKind[]).forEach((kind) => {
          const plan = BUILDINGS[kind];
          const button = el("button", "cbtn");
          button.type = "button";
          button.append(
            el("strong", undefined, plan.name),
            el("span", undefined, `${plan.cost.gold}g · ${plan.cost.timber}t · ${plan.cost.stone}s`),
          );
          button.title = plan.blurb;
          button.addEventListener("click", () => {
            const result = k.build(holding.id, kind);
            this.onSfx(kind === "farms" ? "chop" : "anvil");
            this.act(result.ok, result.message);
          });
          buildRow.append(button);
        });
        detail.append(buildRow);
      } else if (holding.siege && holding.siege.by === k.player) {
        const withdraw = el("button", "cbtn wide", "Lift the siege");
        withdraw.type = "button";
        withdraw.addEventListener("click", () => {
          const result = k.withdraw(holding.id);
          this.onSfx("horn");
          this.act(result.ok, result.message);
        });
        detail.append(withdraw);
      } else {
        const army = k.armyOf(k.player);
        const march = el("button", "cbtn wide gold", "March on this holding");
        march.type = "button";
        march.addEventListener("click", () => {
          const result = k.march(holding.id);
          this.onSfx(result.ok ? "horse-gallop" : "page");
          this.act(result.ok, result.message);
        });
        const odds = el("p", "muted small", `Field army ${army} against ${holding.garrison} garrison and ${holding.walls} wall tiers.`);
        detail.append(march, odds);
      }
    }
    layout.append(mapWrap, detail);
    this.bodyEl.append(layout);
  }

  // ------------------------------------------------------------------ ledger

  private renderLedger(): void {
    const k = this.kingdom;
    const power = k.playerPower;
    const income = k.incomeOf(k.player);
    const upkeep = k.upkeepOf(k.player);

    const grid = el("div", "ledger-grid");
    const resources: Array<[string, number, number]> = [
      ["Gold", power.gold, income.gold - upkeep],
      ["Food", power.food, income.food],
      ["Timber", power.timber, income.timber],
      ["Stone", power.stone, income.stone],
      ["Iron", power.iron, income.iron],
    ];
    for (const [label, value, flow] of resources) {
      const card = el("div", "res-card");
      card.append(
        el("span", "res-label", label),
        el("strong", "res-value", Math.round(value).toLocaleString()),
        el("span", flow >= 0 ? "res-flow up" : "res-flow down", `${flow >= 0 ? "+" : ""}${Math.round(flow)} / day`),
      );
      grid.append(card);
    }
    this.bodyEl.append(grid);

    const tax = el("section", "cpanel");
    tax.append(el("h2", undefined, "Taxation"));
    const taxRow = el("div", "tax-row");
    const range = el("input", "tax-range");
    range.type = "range";
    range.min = "5";
    range.max = "60";
    range.step = "1";
    range.value = String(Math.round(k.taxRate * 100));
    const readout = el("strong", "tax-readout", `${Math.round(k.taxRate * 100)}%`);
    range.addEventListener("input", () => {
      k.setTaxRate(Number(range.value) / 100);
      readout.textContent = `${Math.round(k.taxRate * 100)}%`;
      this.render();
    });
    taxRow.append(range, readout);
    tax.append(
      taxRow,
      el("p", "muted small", "Above 30% the commons grow restless and holdings lose population; markets calm them."),
    );
    this.bodyEl.append(tax);

    const holdings = el("section", "cpanel");
    holdings.append(el("h2", undefined, "Holdings"));
    const list = el("div", "holding-list");
    for (const holding of k.holdings) {
      const house = houseOf(holding.owner);
      const row = el("button", "holding-row");
      row.type = "button";
      row.append(
        el("span", "holding-icon", KIND_ICON[holding.kind]),
        el("span", "holding-name", holding.name),
        el("span", "holding-owner", house.name.replace("The ", "")),
        el("span", "holding-pop", holding.population.toLocaleString()),
        holding.siege ? el("span", "holding-siege", "besieged") : el("span", "holding-siege calm", "peace"),
      );
      row.style.setProperty("--house", rgb(house.banner));
      row.addEventListener("click", () => {
        this.selected = holding.id;
        this.tab = "realm";
        this.render();
      });
      list.append(row);
    }
    holdings.append(list);
    this.bodyEl.append(holdings);

    const standings = el("section", "cpanel");
    standings.append(el("h2", undefined, "Standings"));
    const table = el("table", "standings");
    const head = el("tr");
    for (const label of ["Power", "Holdings", "Army", "Renown", "Strength"]) {
      head.append(el("th", undefined, label));
    }
    table.append(head);
    for (const row of k.standings) {
      const tr = el("tr");
      if (row.id === k.player) tr.classList.add("you");
      const name = el("td");
      const swatch = el("i", "legend-swatch");
      swatch.style.background = rgb(HOUSES[row.id].banner);
      name.append(swatch, document.createTextNode(row.name));
      tr.append(
        name,
        el("td", undefined, String(row.holdings)),
        el("td", undefined, String(row.army)),
        el("td", undefined, String(Math.round(row.renown))),
        el("td", undefined, String(row.strength)),
      );
      table.append(tr);
    }
    standings.append(table);
    this.bodyEl.append(standings);
  }

  // -------------------------------------------------------------------- army

  private renderArmy(): void {
    const k = this.kingdom;
    const power = k.playerPower;
    const summary = el("section", "cpanel");
    summary.append(el("h2", undefined, "The Company"));
    const row = el("div", "army-summary");
    row.append(
      this.stat("Field army", `${k.armyOf(k.player)}`, "power"),
      this.stat("Upkeep", `${k.upkeepOf(k.player)}`, "gold / day"),
      this.stat("Garrisons", `${k.playerHoldings.reduce((sum, holding) => sum + holding.garrison, 0)}`, "men"),
      this.stat("Warband", `${k.fieldArmySize()}`, "followers in the field"),
    );
    summary.append(row);
    const siege = el("img", "tab-banner") as HTMLImageElement;
    siege.src = "art/siege.jpg";
    siege.alt = "Trebuchets and mangonels dragged to the walls of a rival holding.";
    this.bodyEl.append(siege, summary);

    const grid = el("div", "troop-grid");
    for (const id of TROOP_ORDER) {
      const troop = TROOPS[id];
      const card = el("div", "troop-card");
      const glyph = el("div", "troop-glyph", troopGlyph(id));
      const text = el("div", "troop-text");
      text.append(
        el("h3", undefined, troop.name),
        el("p", "muted small", troop.blurb),
        el("p", "troop-cost", `${troop.cost.gold}g · ${troop.cost.food} food · ${troop.cost.iron} iron`),
      );
      const count = el("div", "troop-count");
      count.append(el("span", "muted small", "In service"), el("strong", undefined, String(power.troops[id])));
      const actions = el("div", "troop-actions");
      for (const n of [1, 5]) {
        const buy = el("button", "cbtn small");
        buy.type = "button";
        buy.textContent = `+${n}`;
        buy.addEventListener("click", () => {
          const result = k.recruit(id as TroopId, n);
          this.onSfx(result.ok ? "coins" : "page");
          this.act(result.ok, result.message);
        });
        actions.append(buy);
      }
      const glyphWrap = el("div", "troop-side");
      glyphWrap.append(glyph, count);
      card.append(glyphWrap, text, actions);
      grid.append(card);
    }
    this.bodyEl.append(grid);
  }

  // -------------------------------------------------------------- diplomacy

  private renderDiplomacy(): void {
    const k = this.kingdom;
    const grid = el("div", "diplo-grid");
    for (const house of Object.values(HOUSES)) {
      if (house.id === k.player) continue;
      const power = k.powers[house.id];
      const relation = k.relation(k.player, house.id);
      const atWar = k.isAtWar(k.player, house.id);
      const card = el("div", "diplo-card");
      const head = el("div", "diplo-head");
      head.append(crestSvg(house, 40));
      const words = el("div");
      words.append(
        el("h3", undefined, house.name),
        el("p", "muted small", house.motto),
        el("p", atWar ? "diplo-state war" : "diplo-state", atWar ? "At war" : relation > 45 ? "Friendly" : relation > 10 ? "Wary" : "Cold"),
      );
      head.append(words);
      card.append(head);

      const relationRow = el("div", "meter-label");
      relationRow.append(el("span", undefined, "Opinion"), el("span", undefined, `${Math.round(relation)}`));
      card.append(relationRow, bar(relation + 100, 200, relation >= 0 ? "cbar-fill good" : "cbar-fill danger"));

      const facts = el("div", "diplo-facts");
      facts.append(
        el("span", undefined, `Army ${k.armyOf(house.id)}`),
        el("span", undefined, `Holdings ${k.holdings.filter((holding) => holding.owner === house.id).length}`),
        el("span", undefined, `Renown ${Math.round(power.renown)}`),
      );
      card.append(facts);

      const actions = el("div", "action-grid");
      const gift = el("button", "cbtn");
      gift.type = "button";
      gift.append(el("strong", undefined, "Send a gift"), el("span", undefined, "120 gold · +14 opinion"));
      gift.addEventListener("click", () => {
        const result = k.diplomacy(house.id as PowerId, "gift");
        this.onSfx(result.ok ? "coins" : "page");
        this.act(result.ok, result.message);
      });
      actions.append(gift);

      const treaty = el("button", "cbtn");
      treaty.type = "button";
      const treatyKind = atWar ? "peace" : "alliance";
      treaty.append(
        el("strong", undefined, atWar ? "Sue for peace" : "Propose alliance"),
        el("span", undefined, atWar ? "ends the war if opinion allows" : "needs 45 opinion"),
      );
      treaty.addEventListener("click", () => {
        const result = k.diplomacy(house.id as PowerId, treatyKind);
        this.onSfx(result.ok ? "cheer" : "page");
        this.act(result.ok, result.message);
      });
      actions.append(treaty);

      if (!atWar) {
        const war = el("button", "cbtn danger");
        war.type = "button";
        war.append(el("strong", undefined, "Declare war"), el("span", undefined, "opens the field"));
        war.addEventListener("click", () => {
          const result = k.diplomacy(house.id as PowerId, "war");
          this.onSfx(result.ok ? "war-drums" : "page");
          this.act(result.ok, result.message);
        });
        actions.append(war);
      }
      card.append(actions);
      grid.append(card);
    }
    const harbour = el("img", "tab-banner") as HTMLImageElement;
    harbour.src = "art/port.jpg";
    harbour.alt = "War galleys at the quays of a Silver Sea harbour.";
    this.bodyEl.append(harbour, grid);
  }

  // --------------------------------------------------------------- champions

  private renderChampions(): void {
    const k = this.kingdom;
    const grid = el("div", "champion-grid");
    for (const house of Object.values(HOUSES)) {
      const card = el("article", "champion-card");
      card.style.setProperty("--house", rgb(house.banner));
      const portrait = el("div", "champion-portrait");
      const art = CHAMPION_PORTRAIT[house.id];
      if (art) {
        const image = el("img", "champion-art") as HTMLImageElement;
        image.src = art;
        image.alt = `${CHAMPIONS[house.id] ?? "Warden"}, ${house.name}`;
        image.loading = "lazy";
        portrait.classList.add("has-art");
        portrait.append(image);
      }
      portrait.append(crestSvg(house, art ? 36 : 54));
      const info = el("div", "champion-info");
      info.append(
        el("h3", undefined, CHAMPIONS[house.id] ?? "Warden"),
        el("p", "champion-house", house.name),
        el("p", "muted small", house.motto),
      );
      const weapon = WEAPON_PROFILE[house.weapon];
      const stats = el("div", "champion-stats");
      const stat = (label: string, value: string) => {
        const cell = el("div", "cstat");
        cell.append(el("span", "cstat-label", label), el("strong", "cstat-value", value));
        stats.append(cell);
      };
      stat("Weapon", house.weapon);
      stat("Armour", house.armour);
      stat("Damage", `${Math.round(weapon.damage * 100)}%`);
      stat("Reach", `${weapon.reach.toFixed(1)} m`);
      stat("Speed", `${Math.round(weapon.speed * 100)}%`);
      stat("Standing", `${Math.round(k.powers[house.id].renown)}`);
      info.append(stats);
      card.append(portrait, info);
      grid.append(card);
    }
    this.bodyEl.append(grid);
  }

  // ---------------------------------------------------------------- heraldry

  private renderHeraldry(): void {
    const intro = el("p", "council-blurb");
    intro.textContent =
      "Six coats of arms govern the basin. Every banner, shield, tabard and sail in the world is painted from these fields and charges, so a hall you enter tells you whose it is before a word is spoken.";
    this.bodyEl.append(intro);

    const grid = el("div", "heraldry-grid");
    for (const house of Object.values(HOUSES)) {
      const owned = this.kingdom.holdings.filter((holding) => holding.owner === house.id);
      const card = el("article", "heraldry-card");
      card.style.setProperty("--house", rgb(house.banner));
      card.style.setProperty("--trim", rgb(house.trim));
      const shield = crestSvg(house, 96);
      const words = el("div", "heraldry-words");
      words.append(
        el("h3", undefined, house.name),
        el("p", "heraldry-motto", `“${house.motto}”`),
        el("p", "muted small", `${house.style} tradition · ${house.weapon} · ${house.armour}`),
        el("p", "muted small", `${owned.length} holdings · ${owned.reduce((sum, holding) => sum + holding.population, 0).toLocaleString()} souls`),
      );
      card.append(shield, words);
      grid.append(card);
    }
    this.bodyEl.append(grid);

    const swatches = el("section", "cpanel");
    swatches.append(el("h2", undefined, "Atlas livery"));
    const row = el("div", "swatch-row");
    const tiles: Array<[number, string]> = [
      [ATLAS_TILE.CROSS, "Cross"],
      [ATLAS_TILE.CHEVRON, "Chevron"],
      [ATLAS_TILE.SALTIRE, "Saltire"],
      [ATLAS_TILE.WOLF, "Wolf"],
      [ATLAS_TILE.CRESCENT, "Crescent"],
      [ATLAS_TILE.TOWER, "Tower"],
      [ATLAS_TILE.SUN, "Sun"],
      [ATLAS_TILE.PALES, "Pales"],
    ];
    for (const [, label] of tiles) {
      const chip = el("span", "swatch-chip", label);
      row.append(chip);
    }
    swatches.append(row);
    this.bodyEl.append(swatches);
  }

  // --------------------------------------------------------------- chronicle

  private renderChronicle(): void {
    const banner = el("img", "chronicle-banner") as HTMLImageElement;
    banner.src = "art/battle.jpg";
    banner.alt = "The field armies of the basin meet at dusk.";
    this.bodyEl.append(banner);

    const list = el("div", "chronicle");
    for (const entry of this.kingdom.chronicle) {
      const row = el("div", `chronicle-row ${entry.kind}`);
      row.append(
        el("span", "chronicle-day", `Day ${entry.day}`),
        el("span", "chronicle-text", entry.text),
      );
      list.append(row);
    }
    if (this.kingdom.chronicle.length === 0) {
      list.append(el("p", "muted", "Nothing worth writing down yet."));
    }
    this.bodyEl.append(list);
  }

  // ------------------------------------------------------------------- codex

  private renderCodex(): void {
    const weapons = el("section", "cpanel");
    weapons.append(el("h2", undefined, "Weapons & equipment"));
    const table = el("table", "standings");
    const head = el("tr");
    for (const label of ["Weapon", "Damage", "Speed", "Reach", "Rate"]) {
      head.append(el("th", undefined, label));
    }
    table.append(head);
    for (const [id, profile] of Object.entries(WEAPON_PROFILE)) {
      const tr = el("tr");
      tr.append(
        el("td", undefined, id),
        el("td", undefined, `${Math.round(profile.damage * 100)}%`),
        el("td", undefined, `${Math.round(profile.speed * 100)}%`),
        el("td", undefined, `${profile.reach.toFixed(1)} m`),
        el("td", undefined, profile.rate.toFixed(1)),
      );
      table.append(tr);
    }
    weapons.append(table);
    this.bodyEl.append(weapons);

    const troops = el("section", "cpanel");
    troops.append(el("h2", undefined, "Soldiery"));
    const troopList = el("div", "codex-list");
    for (const id of TROOP_ORDER) {
      const troop = TROOPS[id];
      const row = el("div", "codex-row");
      row.append(
        el("span", "codex-glyph", troopGlyph(id)),
        el("strong", undefined, troop.name),
        el("span", "muted small", troop.blurb),
        el("span", "codex-figure", `power ${troop.power} · upkeep ${troop.upkeep}`),
      );
      troopList.append(row);
    }
    troops.append(troopList);
    this.bodyEl.append(troops);

    const works = el("section", "cpanel");
    works.append(el("h2", undefined, "Works"));
    const workList = el("div", "codex-list");
    for (const plan of Object.values(BUILDINGS)) {
      const row = el("div", "codex-row");
      row.append(
        el("strong", undefined, plan.name),
        el("span", "muted small", plan.blurb),
        el("span", "codex-figure", `${plan.cost.gold}g · ${plan.cost.timber} timber · ${plan.cost.stone} stone`),
      );
      workList.append(row);
    }
    works.append(workList);
    this.bodyEl.append(works);

    const note = el("p", "council-blurb");
    note.textContent =
      "The basin is generated, not imported: terrain, forests, keeps, ports and every figure are assembled from the engine's own primitives and painted from one 1024-pixel atlas at boot. That is why the world is dense and the install stays small.";
    this.bodyEl.append(note);
  }
}

function troopGlyph(id: TroopId): string {
  switch (id) {
    case "levy": return "⚒";
    case "spear": return "⑂";
    case "archer": return "➶";
    case "knight": return "♞";
    case "siege": return "⌂";
    case "galley": return "⛵";
  }
}

export type { HouseId };
