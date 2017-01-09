// Type definitions for yang-js
// Project: https://github.com/corenova/yang-js
// Definitions by: Peter Lee <https://github.com/corenova>
// Definitions: https://github.com/DefinitelyTyped/DefinitelyTyped

declare var Yang: schema.Yang;

declare namespace schema {
  export interface Yang {
	new (schema: string): IExpression;
	use(...args: any[]): any;
  }
  export interface Expression {
	locate: any;
  }
}

export = Yang
