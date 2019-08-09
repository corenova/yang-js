// Type definitions for yang-js
// Project: yang-js
// Definitions by: quan.tang
import EventEmitter = NodeJS.EventEmitter;

export function parse(schema: string): YangInstance;
export function compose(data: any): YangInstance;
export function resolve(name: any): YangInstance;
export function clear(): void;


export interface YangInstance {
    bind(obj: any): this;
    eval(data?: any): YangModel;
    validate(data: any): any;
    extends(schema: string): this;
}

export interface YangModel extends YangProperty {
    access(model: string): YangModel;
    on(event: string, path: string, callback: any): EventEmitter;
}

export interface YangProperty {
    name: string;
    parent: YangProperty;
    path: YangXPath;
    children: YangProperty[];
    schema: any;
    change: any[];

    get(key?: string): any;
    set(value: any): this;
    merge(value: any): this;
    create(value: any): this;
    detach(): this;
    find(pattern?: string): YangProperty;
    in(pattern?: string): YangProperty;
    do(): Promise<any>;
    toJSON(tag?: boolean): any;
}

export interface YangXPath {
    tail: YangXPath;
    contains(path: string): boolean;
    locate(path: string): YangXPath;
}

export function _import(name: string): YangInstance;
export {_import as import};
