// Minimal typing for the one `pg` API used directly (see main.ts); the rest
// of the app talks to Postgres through TypeORM. Replace with `@types/pg` if
// more of it is ever needed.
declare module 'pg' {
  const pg: {
    types: { setTypeParser(oid: number, parser: (value: string) => unknown): void };
  };
  export default pg;
}
