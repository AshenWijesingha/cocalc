/*
# Example usage

```ts
interface SaleRecord {
  name: string;
  price: number;
  time?: number; // This can be omitted
}

let Sale = createTypedMap<SaleRecord>();
let sale1 = new Sale({ name: "Latte", price: 10 });
let sale2 = sale1.set("name", "Mocha");
```

For more information see "app-framework/examples/"
*/
import { Map, List } from "immutable";
import { DeepImmutable } from "./immutable-types";
import { CopyMaybe, Copy2Maybes, Copy3Maybes } from "./immutable-types";

// There has to be a better way to move across TypedMap/immutable.Map boundaries...
type Value<T> = T extends Map<string, infer V>
  ? V
  : T extends List<infer V>
  ? V
  : never;
type State<T> = T extends TypedMap<infer TP> ? TP : never;

type Drill1<Top, K1 extends keyof Top> = NonNullable<Top[K1]>;
type Drill2<
  Top,
  K1 extends keyof Top,
  K2 extends keyof Drill1<Top, K1>
> = NonNullable<Drill1<Top, K1>[K2]>;
type Drill3<
  Top,
  K1 extends keyof Top,
  K2 extends keyof Drill1<Top, K1>,
  K3 extends keyof Drill2<Top, K1, K2>
> = NonNullable<Drill2<Top, K1, K2>[K3]>;

export interface TypedMap<TProps extends Object> {
  size: number;

  // Reading values
  has(key: string): boolean;

  /**
   * Returns the value associated with the provided key.
   *
   * If the requested key is undefined, then
   * notSetValue will be returned if provided.
   */
  get<K extends keyof TProps>(field: K): DeepImmutable<TProps[K]>;
  get<K extends keyof TProps, NSV>(
    field: K,
    notSetValue: NSV
  ): NonNullable<DeepImmutable<TProps[K]>> | NSV;
  get<K extends keyof TProps>(key: K): TProps[K];
  get<K extends keyof TProps, NSV>(
    key: K,
    notSetValue: NSV
  ): NonNullable<TProps[K]> | NSV;
  get<K extends keyof TProps, NSV>(key: K, notSetValue?: NSV): TProps[K] | NSV;

  // Reading deep values
  hasIn(keyPath: Iterable<any>): boolean;

  // Only works 3 levels deep.
  // It's probably advisable to normalize your data if you find yourself that deep
  // https://redux.js.org/recipes/structuring-reducers/normalizing-state-shape
  // If you need to describe a recurse data structure such as a binary tree, use unsafe_getIn.
  // Same code exists in Store.ts
  getIn<K1 extends keyof TProps>(path: [K1]): DeepImmutable<TProps[K1]>;
  getIn<K1 extends keyof TProps, K2 extends keyof NonNullable<TProps[K1]>>(
    path: [K1, K2]
  ): DeepImmutable<CopyMaybe<TProps[K1], NonNullable<TProps[K1]>[K2]>>;
  getIn<K1 extends keyof TProps, K2 extends string>( // Operating on TypedMap<{ foo: immutable.Map<K2, V> }>
    path: [K1, K2]
  ): DeepImmutable<CopyMaybe<TProps[K1], Value<NonNullable<TProps[K1]>>>>;
  getIn<
    K1 extends keyof TProps,
    K2 extends keyof NonNullable<TProps[K1]>,
    K3 extends keyof NonNullable<NonNullable<TProps[K1]>[K2]>
  >(
    path: [K1, K2, K3]
  ): DeepImmutable<
    Copy2Maybes<
      TProps[K1],
      NonNullable<TProps[K1]>[K2],
      NonNullable<NonNullable<TProps[K1]>[K2]>[K3]
    >
  >;
  getIn<
    // Operating on TypedMap<{ foo: immutable.Map<K2, V}> where V: TypedMap<any>
    K1 extends keyof TProps,
    K2 extends string, // Key type of Map<string, unknown>
    K3 extends keyof State<Value<NonNullable<TProps[K1]>>>
  >(
    path: [K1, K2, K3]
  ): DeepImmutable<
    Copy2Maybes<
      TProps[K1],
      Value<NonNullable<TProps[K1]>>,
      NonNullable<State<Value<NonNullable<TProps[K1]>>>[K3]>
    >
  >;
  getIn<
    K1 extends keyof TProps,
    K2 extends keyof Drill1<TProps, K1>,
    K3 extends keyof Drill2<TProps, K1, K2>,
    K4 extends keyof Drill3<TProps, K1, K2, K3>,
  >(
    path: [K1, K2, K3, K4]
  ): DeepImmutable<
    Copy3Maybes<
      TProps[K1],
      Drill1<TProps, K1>[K2],
      Drill2<TProps, K1, K2>[K3],
      Drill3<TProps, K1, K2, K3>[K4]
    >
  >;
  getIn<K1 extends keyof TProps, NSV>(
    path: [K1],
    notSetValue: NSV
  ): NonNullable<DeepImmutable<TProps[K1]>> | NSV;
  getIn<K1 extends keyof TProps, K2 extends keyof NonNullable<TProps[K1]>, NSV>(
    path: [K1, K2],
    notSetValue: NSV
  ): DeepImmutable<NonNullable<TProps[K1]>[K2]> | NSV;
  getIn<K1 extends keyof TProps, K2 extends string, NSV>( // Operating on TypedMap<{ foo: immutable.Map<K2, V> }>
    path: [K1, K2],
    NotSetValue: NSV
  ): NonNullable<DeepImmutable<Value<NonNullable<TProps[K1]>>>> | NSV;
  getIn<
    K1 extends keyof TProps,
    K2 extends keyof NonNullable<TProps[K1]>,
    K3 extends keyof NonNullable<NonNullable<TProps[K1]>[K2]>,
    NSV
  >(
    path: [K1, K2, K3],
    notSetValue: NSV
  ): DeepImmutable<NonNullable<NonNullable<TProps[K1]>[K2]>[K3]> | NSV;
  getIn<
    K1 extends keyof TProps,
    K2 extends keyof NonNullable<TProps[K1]>,
    K3 extends keyof NonNullable<NonNullable<TProps[K1]>[K2]>,
    K4 extends keyof NonNullable<NonNullable<NonNullable<TProps[K1]>[K2]>[K3]>,
    NSV
  >(
    path: [K1, K2, K3, K4],
    notSetValue: NSV
  ):
    | DeepImmutable<
        NonNullable<NonNullable<NonNullable<TProps[K1]>[K2]>[K3]>[K4]
      >
    | NSV;

  // Value equality
  equals(other: any): boolean;
  hashCode(): number;

  // Persistent changes
  set<K extends keyof TProps>(key: K, value: TProps[K]): this;
  update<K extends keyof TProps>(
    key: K,
    updater: (value: TProps[K]) => TProps[K]
  ): this;
  merge(...collections: Array<Partial<TProps> | Iterable<[string, any]>>): this;
  mergeDeep(
    ...collections: Array<Partial<TProps> | Iterable<[string, any]>>
  ): this;

  mergeWith(
    merger: (oldVal: any, newVal: any, key: keyof TProps) => any,
    ...collections: Array<Partial<TProps> | Iterable<[string, any]>>
  ): this;
  mergeDeepWith(
    merger: (oldVal: any, newVal: any, key: any) => any,
    ...collections: Array<Partial<TProps> | Iterable<[string, any]>>
  ): this;

  /**
   * Returns a new instance of this Record type with the value for the
   * specific key set to its default value.
   *
   * @alias remove
   */
  delete<K extends keyof TProps>(key: K): this;
  remove<K extends keyof TProps>(key: K): this;

  // Deep persistent changes
  setIn(keyPath: Iterable<any>, value: any): this;
  updateIn(keyPath: Iterable<any>, updater: (value: any) => any): this;
  mergeIn(keyPath: Iterable<any>, ...collections: Array<any>): this;
  mergeDeepIn(keyPath: Iterable<any>, ...collections: Array<any>): this;

  /**
   * @alias removeIn
   */
  deleteIn(keyPath: Iterable<any>): this;
  removeIn(keyPath: Iterable<any>): this;

  // Conversion to JavaScript types
  /**
   * Deeply converts this Record to equivalent native JavaScript Object.
   */
  toJS(): { [K in keyof TProps]: any };

  /**
   * Shallowly converts this Record to equivalent native JavaScript Object.
   */
  toJSON(): TProps;

  // Transient changes
  /**
   * Note: Not all methods can be used on a mutable collection or within
   * `withMutations`! Only `set` may be used mutatively.
   *
   * @see `Map#withMutations`
   */
  withMutations(mutator: (mutable: this) => any): this;

  /**
   * @see `Map#asMutable`
   */
  asMutable(): this;

  /**
   * @see `Map#wasAltered`
   */
  wasAltered(): boolean;

  /**
   * @see `Map#asImmutable`
   */
  asImmutable(): this;

  [Symbol.iterator](): IterableIterator<[keyof TProps, TProps[keyof TProps]]>;

  filter(fn: (predicate) => boolean): this;
}

interface TypedMapFactory<TProps extends Object> {
  new (values: TProps): TypedMap<TProps>;
}

export function typedMap<TProps extends object>(
  defaults: Partial<TProps> = {}
): TypedMap<TProps> {
  return Map(defaults) as any;
}

export function createTypedMap<OuterProps extends Object>(
  defaults?: Partial<
    OuterProps extends TypedMap<infer InnerProps> ? InnerProps : OuterProps
  >
): TypedMapFactory<
  OuterProps extends TypedMap<infer InnerProps> ? InnerProps : OuterProps
> {
  let default_map: Map<any, any>;
  if (defaults !== undefined) {
    default_map = Map(defaults as any);
  }

  type TProps = OuterProps extends TypedMap<infer InnerProps>
    ? InnerProps
    : OuterProps;

  class _TypedMap {
    private data: any;

    constructor(TProps: TProps) {
      if (default_map !== undefined) {
        this.data = default_map.merge(TProps as any);
      } else {
        this.data = Map(TProps as any);
      }
      // Allows this TypedMap to disguise itself to immutable.js
      this["@@__IMMUTABLE_ITERABLE__@@"] = true;
    }

    // Reading values
    has(key: string | number | symbol): key is keyof TProps {
      return this.data.has(key);
    }

    /**
     * Returns the value associated with the provided key, which may be the
     * default value defined when creating the Record factory function.
     *
     * If the requested key is not defined by this Record type, then
     * notSetValue will be returned if provided. Note that this scenario would
     * produce an error when using Flow or TypeScript.
     */
    get<K extends keyof TProps>(key: K): TProps[K];
    get<K extends keyof TProps, NSV>(key: K, notSetValue: NSV): TProps[K] | NSV;
    get<K extends keyof TProps, NSV>(
      key: K,
      notSetValue?: NSV
    ): TProps[K] | NSV {
      return this.data.get(key, notSetValue);
    }

    // Reading deep values
    hasIn(keyPath: Iterable<any>): boolean {
      return this.data.hasIn(keyPath);
    }
    getIn(keyPath: Iterable<any>, notSetValue?: any): any {
      return this.data.getIn(keyPath, notSetValue);
    }

    // Value equality
    equals(other: any): boolean {
      return this.data.equals(other);
    }
    hashCode(): number {
      return this.data.hashCode();
    }

    // Persistent changes
    set<K extends keyof TProps>(key: K, value: TProps[K]): this {
      return this.data.set(key, value);
    }
    update<K extends keyof TProps>(
      key: K,
      updater: (value: TProps[K]) => TProps[K]
    ): this {
      return this.data.update(key, updater);
    }
    merge(
      ...collections: Array<Partial<TProps> | Iterable<[string, any]>>
    ): this {
      return this.data.merge(collections);
    }
    mergeDeep(
      ...collections: Array<Partial<TProps> | Iterable<[string, any]>>
    ): this {
      return this.data.mergeDeep(collections);
    }

    mergeWith(
      merger: (oldVal: any, newVal: any, key: keyof TProps) => any,
      ...collections: Array<Partial<TProps> | Iterable<[string, any]>>
    ): this {
      return this.data.mergeWith(merger, collections);
    }
    mergeDeepWith(
      merger: (oldVal: any, newVal: any, key: any) => any,
      ...collections: Array<Partial<TProps> | Iterable<[string, any]>>
    ): this {
      return this.data.mergeDeepWith(merger, collections);
    }

    /**
     * Returns a new instance of this Record type with the value for the
     * specific key set to its default value.
     *
     * @alias remove
     */
    delete<K extends keyof TProps>(key: K): this {
      return this.data.delete(key);
    }
    remove<K extends keyof TProps>(key: K): this {
      return this.data.remove(key);
    }

    // Deep persistent changes
    setIn(keyPath: Iterable<any>, value: any): this {
      return this.data.setIn(keyPath, value);
    }
    updateIn(keyPath: Iterable<any>, updater: (value: any) => any): this {
      return this.data.updateIn(keyPath, updater);
    }
    mergeIn(keyPath: Iterable<any>, ...collections: Array<any>): this {
      return this.data.mergIn(keyPath, collections);
    }
    mergeDeepIn(keyPath: Iterable<any>, ...collections: Array<any>): this {
      return this.data.mergeDeepIn(keyPath, collections);
    }

    /**
     * @alias removeIn
     */
    deleteIn(keyPath: Iterable<any>): this {
      return this.data.deleteIn(keyPath);
    }
    removeIn(keyPath: Iterable<any>): this {
      return this.data.removeIn(keyPath);
    }

    // Conversion to JavaScript types
    /**
     * Deeply converts this Record to equivalent native JavaScript Object.
     */
    toJS(): { [K in keyof TProps]: any } {
      return this.data.toJS();
    }

    /**
     * Shallowly converts this Record to equivalent native JavaScript Object.
     */
    toJSON(): TProps {
      return this.data.toJSON();
    }

    // Transient changes
    /**
     * Note: Not all methods can be used on a mutable collection or within
     * `withMutations`! Only `set` may be used mutatively.
     *
     * @see `Map#withMutations`
     */
    withMutations(mutator: (mutable: this) => any): this {
      return this.data.withMutations(mutator);
    }

    /**
     * @see `Map#asMutable`
     */
    asMutable(): this {
      return this.data.asMutable();
    }

    /**
     * @see `Map#wasAltered`
     */
    wasAltered(): boolean {
      return this.data.wasAltered();
    }

    /**
     * @see `Map#asImmutable`
     */
    asImmutable(): this {
      return this.data.asImmutable();
    }

    get size(): number {
      return this.data.size;
    }
  }

  return _TypedMap as any;
}
