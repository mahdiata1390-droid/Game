// A compact entity/component store. Components are plain objects keyed by name;
// systems are ordinary functions registered with a fixed tick order.

export type Entity = number;
export type ComponentSet = Record<string, object>;

export class World {
  private nextId = 1;
  private readonly alive = new Set<Entity>();
  private readonly stores = new Map<string, Map<Entity, object>>();

  create(components: ComponentSet = {}): Entity {
    const id = this.nextId++;
    this.alive.add(id);
    for (const [name, value] of Object.entries(components)) this.store(name).set(id, value);
    return id;
  }

  destroy(id: Entity): void {
    this.alive.delete(id);
    for (const store of this.stores.values()) store.delete(id);
  }

  has(id: Entity): boolean {
    return this.alive.has(id);
  }

  get<T extends object>(id: Entity, name: string): T | undefined {
    return this.stores.get(name)?.get(id) as T | undefined;
  }

  require<T extends object>(id: Entity, name: string): T {
    const value = this.get<T>(id, name);
    if (!value) throw new Error(`entity ${id} is missing component "${name}"`);
    return value;
  }

  set(id: Entity, name: string, value: object): void {
    this.store(name).set(id, value);
  }

  remove(id: Entity, name: string): void {
    this.stores.get(name)?.delete(id);
  }

  /** All live entities that have every one of the named components. */
  query(...names: string[]): Entity[] {
    if (names.length === 0) return [...this.alive];
    let smallest = this.store(names[0]);
    for (const name of names) {
      const store = this.store(name);
      if (store.size < smallest.size) smallest = store;
    }
    const out: Entity[] = [];
    outer: for (const id of smallest.keys()) {
      if (!this.alive.has(id)) continue;
      for (const name of names) if (!this.store(name).has(id)) continue outer;
      out.push(id);
    }
    return out;
  }

  entities(): Entity[] {
    return [...this.alive];
  }

  counts(): { entities: number; components: Record<string, number> } {
    const components: Record<string, number> = {};
    for (const [name, store] of this.stores) components[name] = store.size;
    return { entities: this.alive.size, components };
  }

  private store(name: string): Map<Entity, object> {
    let s = this.stores.get(name);
    if (!s) {
      s = new Map();
      this.stores.set(name, s);
    }
    return s;
  }
}
