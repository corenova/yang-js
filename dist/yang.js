(function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
/*!
 Based on ndef.parser, by Raphael Graf(r@undefined.ch)
 http://www.undefined.ch/mparser/index.html

 Ported to JavaScript and modified by Matthew Crumley (email@matthewcrumley.com, http://silentmatt.com/)

 You are free to use and modify this code in anyway you find useful. Please leave this comment in the code
 to acknowledge its original source. If you feel like it, I enjoy hearing about projects that use my code,
 but don't feel like you have to let me know or ask permission.
*/

//  Added by stlsmiths 6/13/2011
//  re-define Array.indexOf, because IE doesn't know it ...
//
//  from http://stellapower.net/content/javascript-support-and-arrayindexof-ie
	if (!Array.indexOf) {
		Array.prototype.indexOf = function (obj, start) {
			for (var i = (start || 0); i < this.length; i++) {
				if (this[i] === obj) {
					return i;
				}
			}
			return -1;
		}
	}

var Parser = (function (scope) {
	function object(o) {
		function F() {}
		F.prototype = o;
		return new F();
	}

	var TNUMBER = 0;
	var TOP1 = 1;
	var TOP2 = 2;
	var TVAR = 3;
	var TFUNCALL = 4;

	function Token(type_, index_, prio_, number_) {
		this.type_ = type_;
		this.index_ = index_ || 0;
		this.prio_ = prio_ || 0;
		this.number_ = (number_ !== undefined && number_ !== null) ? number_ : 0;
		this.toString = function () {
			switch (this.type_) {
			case TNUMBER:
				return this.number_;
			case TOP1:
			case TOP2:
			case TVAR:
				return this.index_;
			case TFUNCALL:
				return "CALL";
			default:
				return "Invalid Token";
			}
		};
	}

	function Expression(tokens, ops1, ops2, functions) {
		this.tokens = tokens;
		this.ops1 = ops1;
		this.ops2 = ops2;
		this.functions = functions;
	}

	// Based on http://www.json.org/json2.js
    var cx = /[\u0000\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,
        escapable = /[\\\'\x00-\x1f\x7f-\x9f\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,
        meta = {    // table of character substitutions
            '\b': '\\b',
            '\t': '\\t',
            '\n': '\\n',
            '\f': '\\f',
            '\r': '\\r',
            "'" : "\\'",
            '\\': '\\\\'
        };

	function escapeValue(v) {
		if (typeof v === "string") {
			escapable.lastIndex = 0;
	        return escapable.test(v) ?
	            "'" + v.replace(escapable, function (a) {
	                var c = meta[a];
	                return typeof c === 'string' ? c :
	                    '\\u' + ('0000' + a.charCodeAt(0).toString(16)).slice(-4);
	            }) + "'" :
	            "'" + v + "'";
		}
		return v;
	}

	function hasValue(values, index) {
		var parts = index.split(/\./);
		var value = values;
		var part;
		while (part = parts.shift()) {
			if (!(part in value)) {
				return false;
			}
			value = value[part];
		}
		return true;
	}

	function getValue(values, index) {
		var parts = index.split(/\./);
		var value = values;
		var part;
		while (part = parts.shift()) {
			value = value[part];
		}
		return value;
	}

	Expression.prototype = {
		simplify: function (values) {
			values = values || {};
			var nstack = [];
			var newexpression = [];
			var n1;
			var n2;
			var f;
			var L = this.tokens.length;
			var item;
			var i = 0;
			for (i = 0; i < L; i++) {
				item = this.tokens[i];
				var type_ = item.type_;
				if (type_ === TNUMBER) {
					nstack.push(item);
				}
				else if (type_ === TVAR && hasValue(values, item.index_)) {
					item = new Token(TNUMBER, 0, 0, getValue(values, item.index_));
					nstack.push(item);
				}
				else if (type_ === TOP2 && nstack.length > 1) {
					n2 = nstack.pop();
					n1 = nstack.pop();
					f = this.ops2[item.index_];
					item = new Token(TNUMBER, 0, 0, f(n1.number_, n2.number_));
					nstack.push(item);
				}
				else if (type_ === TOP1 && nstack.length > 0) {
					n1 = nstack.pop();
					f = this.ops1[item.index_];
					item = new Token(TNUMBER, 0, 0, f(n1.number_));
					nstack.push(item);
				}
				else {
					while (nstack.length > 0) {
						newexpression.push(nstack.shift());
					}
					newexpression.push(item);
				}
			}
			while (nstack.length > 0) {
				newexpression.push(nstack.shift());
			}

			return new Expression(newexpression, object(this.ops1), object(this.ops2), object(this.functions));
		},

		substitute: function (variable, expr) {
			if (!(expr instanceof Expression)) {
				expr = new Parser().parse(String(expr));
			}
			var newexpression = [];
			var L = this.tokens.length;
			var item;
			var i = 0;
			for (i = 0; i < L; i++) {
				item = this.tokens[i];
				var type_ = item.type_;
				if (type_ === TVAR && item.index_ === variable) {
					for (var j = 0; j < expr.tokens.length; j++) {
						var expritem = expr.tokens[j];
						var replitem = new Token(expritem.type_, expritem.index_, expritem.prio_, expritem.number_);
						newexpression.push(replitem);
					}
				}
				else {
					newexpression.push(item);
				}
			}

			var ret = new Expression(newexpression, object(this.ops1), object(this.ops2), object(this.functions));
			return ret;
		},

		evaluate: function (values) {
			values = values || {};
			var nstack = [];
			var n1;
			var n2;
			var f;
			var L = this.tokens.length;
			var item;
			var i = 0;
			for (i = 0; i < L; i++) {
				item = this.tokens[i];
				var type_ = item.type_;
				if (type_ === TNUMBER) {
					nstack.push(item.number_);
				}
				else if (type_ === TOP2) {
					n2 = nstack.pop();
					n1 = nstack.pop();
					f = this.ops2[item.index_];
					nstack.push(f(n1, n2));
				}
				else if (type_ === TVAR) {
					if (hasValue(values, item.index_)) {
						nstack.push(getValue(values, item.index_));
					}
					else if (hasValue(this.functions, item.index_)) {
						nstack.push(getValue(this.functions, item.index_));
					}
					else {
						throw new Error("undefined variable: " + item.index_);
					}
				}
				else if (type_ === TOP1) {
					n1 = nstack.pop();
					f = this.ops1[item.index_];
					nstack.push(f(n1));
				}
				else if (type_ === TFUNCALL) {
					n1 = nstack.pop();
					f = nstack.pop();
					if (f.apply && f.call) {
						if (Object.prototype.toString.call(n1) == "[object Array]") {
							nstack.push(f.apply(undefined, n1));
						}
						else {
							nstack.push(f.call(undefined, n1));
						}
					}
					else {
						throw new Error(f + " is not a function");
					}
				}
				else {
					throw new Error("invalid Expression");
				}
			}
			if (nstack.length > 1) {
				throw new Error("invalid Expression (parity)");
			}
			return nstack[0];
		},

		toString: function (toJS) {
			var nstack = [];
			var n1;
			var n2;
			var f;
			var L = this.tokens.length;
			var item;
			var i = 0;
			for (i = 0; i < L; i++) {
				item = this.tokens[i];
				var type_ = item.type_;
				if (type_ === TNUMBER) {
					nstack.push(escapeValue(item.number_));
				}
				else if (type_ === TOP2) {
					n2 = nstack.pop();
					n1 = nstack.pop();
					f = item.index_;
					if (toJS && f == "^") {
						nstack.push("Math.pow(" + n1 + "," + n2 + ")");
					}
					else {
						nstack.push("(" + n1 + f + n2 + ")");
					}
				}
				else if (type_ === TVAR) {
					nstack.push(item.index_);
				}
				else if (type_ === TOP1) {
					n1 = nstack.pop();
					f = item.index_;
					if (f === "-") {
						nstack.push("(" + f + n1 + ")");
					}
					else {
						nstack.push(f + "(" + n1 + ")");
					}
				}
				else if (type_ === TFUNCALL) {
					n1 = nstack.pop();
					f = nstack.pop();
					nstack.push(f + "(" + n1 + ")");
				}
				else {
					throw new Error("invalid Expression");
				}
			}
			if (nstack.length > 1) {
				throw new Error("invalid Expression (parity)");
			}
			return nstack[0];
		},

		variables: function () {
			var L = this.tokens.length;
			var vars = [];
			for (var i = 0; i < L; i++) {
				var item = this.tokens[i];
				if (item.type_ === TVAR && (vars.indexOf(item.index_) == -1)) {
					vars.push(item.index_);
				}
			}

			return vars;
		},

		toJSFunction: function (param, variables) {
			var f = new Function(param, "with(Parser.values) { return " + this.simplify(variables).toString(true) + "; }");
			return f;
		}
	};

	function add(a, b) {
		return Number(a) + Number(b);
	}
	function sub(a, b) {
		return a - b;
	}
	function mul(a, b) {
		return a * b;
	}
	function div(a, b) {
		return a / b;
	}
	function mod(a, b) {
		return a % b;
	}
	function concat(a, b) {
		return "" + a + b;
	}
	function equal(a, b) {
		return a == b;
	}
	function notEqual(a, b) {
		return a != b;
	}
	function greaterThan(a, b) {
		return a > b;
	}
	function lessThan(a, b) {
		return a < b;
	}
	function greaterThanEqual(a, b) {
		return a >= b;
	}
	function lessThanEqual(a, b) {
		return a <= b;
	}
	function andOperator(a, b) {
		return Boolean(a && b);
	}
	function orOperator(a, b) {
		return Boolean(a || b);
	}
	function sinh(a) {
		return Math.sinh ? Math.sinh(a) : ((Math.exp(a) - Math.exp(-a)) / 2);
	}
	function cosh(a) {
		return Math.cosh ? Math.cosh(a) : ((Math.exp(a) + Math.exp(-a)) / 2);
	}
	function tanh(a) {
		if (Math.tanh) return Math.tanh(a);
		if(a === Infinity) return 1;
		if(a === -Infinity) return -1;
		return (Math.exp(a) - Math.exp(-a)) / (Math.exp(a) + Math.exp(-a));
	}
	function asinh(a) {
		if (Math.asinh) return Math.asinh(a);
		if(a === -Infinity) return a;
		return Math.log(a + Math.sqrt(a * a + 1));
	}
	function acosh(a) {
		return Math.acosh ? Math.acosh(a) : Math.log(a + Math.sqrt(a * a - 1));
	}
	function atanh(a) {
		return Math.atanh ? Math.atanh(a) : (Math.log((1+a)/(1-a)) / 2);
	}
	function log10(a) {
	      return Math.log(a) * Math.LOG10E;
	}
	function neg(a) {
		return -a;
	}
	function trunc(a) {
		if(Math.trunc) return Math.trunc(a);
		else return a < 0 ? Math.ceil(a) : Math.floor(a);
	}
	function random(a) {
		return Math.random() * (a || 1);
	}
	function fac(a) { //a!
		a = Math.floor(a);
		var b = a;
		while (a > 1) {
			b = b * (--a);
		}
		return b;
	}

	// TODO: use hypot that doesn't overflow
	function hypot() {
		if(Math.hypot) return Math.hypot.apply(this, arguments);
		var y = 0;
		var length = arguments.length;
		for (var i = 0; i < length; i++) {
			if (arguments[i] === Infinity || arguments[i] === -Infinity) {
				return Infinity;
			}
			y += arguments[i] * arguments[i];
		}
		return Math.sqrt(y);
	}

	function condition(cond, yep, nope) {
		return cond ? yep : nope;
	}

	function append(a, b) {
		if (Object.prototype.toString.call(a) != "[object Array]") {
			return [a, b];
		}
		a = a.slice();
		a.push(b);
		return a;
	}

	function Parser() {
		this.success = false;
		this.errormsg = "";
		this.expression = "";

		this.pos = 0;

		this.tokennumber = 0;
		this.tokenprio = 0;
		this.tokenindex = 0;
		this.tmpprio = 0;

		this.ops1 = {
			"sin": Math.sin,
			"cos": Math.cos,
			"tan": Math.tan,
			"asin": Math.asin,
			"acos": Math.acos,
			"atan": Math.atan,
			"sinh": sinh,
			"cosh": cosh,
			"tanh": tanh,
			"asinh": asinh,
			"acosh": acosh,
			"atanh": atanh,
			"sqrt": Math.sqrt,
			"log": Math.log,
			"lg" : log10,
			"log10" : log10,
			"abs": Math.abs,
			"ceil": Math.ceil,
			"floor": Math.floor,
			"round": Math.round,
			"trunc": trunc,
			"-": neg,
			"exp": Math.exp
		};

		this.ops2 = {
			"+": add,
			"-": sub,
			"*": mul,
			"/": div,
			"%": mod,
			"^": Math.pow,
			",": append,
			"||": concat,
			"==": equal,
			"!=": notEqual,
			">": greaterThan,
			"<": lessThan,
			">=": greaterThanEqual,
			"<=": lessThanEqual,
			"and": andOperator,
			"or": orOperator
		};

		this.functions = {
			"random": random,
			"fac": fac,
			"min": Math.min,
			"max": Math.max,
			"hypot": hypot,
			"pyt": hypot, // backward compat
			"pow": Math.pow,
			"atan2": Math.atan2,
			"if": condition
		};

		this.consts = {
			"E": Math.E,
			"PI": Math.PI
		};
	}

	Parser.parse = function (expr) {
		return new Parser().parse(expr);
	};

	Parser.evaluate = function (expr, variables) {
		return Parser.parse(expr).evaluate(variables);
	};

	Parser.Expression = Expression;

	Parser.values = {
		sin: Math.sin,
		cos: Math.cos,
		tan: Math.tan,
		asin: Math.asin,
		acos: Math.acos,
		atan: Math.atan,
		sinh: sinh,
		cosh: cosh,
		tanh: tanh,
		asinh: asinh,
		acosh: acosh,
		atanh: atanh,
		sqrt: Math.sqrt,
		log: Math.log,
		lg: log10,
		log10: log10,
		abs: Math.abs,
		ceil: Math.ceil,
		floor: Math.floor,
		round: Math.round,
		trunc: trunc,
		random: random,
		fac: fac,
		exp: Math.exp,
		min: Math.min,
		max: Math.max,
		hypot: hypot,
		pyt: hypot, // backward compat
		pow: Math.pow,
		atan2: Math.atan2,
		"if": condition,
		E: Math.E,
		PI: Math.PI
	};

	var PRIMARY      = 1 << 0;
	var OPERATOR     = 1 << 1;
	var FUNCTION     = 1 << 2;
	var LPAREN       = 1 << 3;
	var RPAREN       = 1 << 4;
	var COMMA        = 1 << 5;
	var SIGN         = 1 << 6;
	var CALL         = 1 << 7;
	var NULLARY_CALL = 1 << 8;

	Parser.prototype = {
		parse: function (expr) {
			this.errormsg = "";
			this.success = true;
			var operstack = [];
			var tokenstack = [];
			this.tmpprio = 0;
			var expected = (PRIMARY | LPAREN | FUNCTION | SIGN);
			var noperators = 0;
			this.expression = expr;
			this.pos = 0;

			while (this.pos < this.expression.length) {
				if (this.isOperator()) {
					if (this.isSign() && (expected & SIGN)) {
						if (this.isNegativeSign()) {
							this.tokenprio = 2;
							this.tokenindex = "-";
							noperators++;
							this.addfunc(tokenstack, operstack, TOP1);
						}
						expected = (PRIMARY | LPAREN | FUNCTION | SIGN);
					}
					else if (this.isComment()) {

					}
					else {
						if ((expected & OPERATOR) === 0) {
							this.error_parsing(this.pos, "unexpected operator");
						}
						noperators += 2;
						this.addfunc(tokenstack, operstack, TOP2);
						expected = (PRIMARY | LPAREN | FUNCTION | SIGN);
					}
				}
				else if (this.isNumber()) {
					if ((expected & PRIMARY) === 0) {
						this.error_parsing(this.pos, "unexpected number");
					}
					var token = new Token(TNUMBER, 0, 0, this.tokennumber);
					tokenstack.push(token);

					expected = (OPERATOR | RPAREN | COMMA);
				}
				else if (this.isString()) {
					if ((expected & PRIMARY) === 0) {
						this.error_parsing(this.pos, "unexpected string");
					}
					var token = new Token(TNUMBER, 0, 0, this.tokennumber);
					tokenstack.push(token);

					expected = (OPERATOR | RPAREN | COMMA);
				}
				else if (this.isLeftParenth()) {
					if ((expected & LPAREN) === 0) {
						this.error_parsing(this.pos, "unexpected \"(\"");
					}

					if (expected & CALL) {
						noperators += 2;
						this.tokenprio = -2;
						this.tokenindex = -1;
						this.addfunc(tokenstack, operstack, TFUNCALL);
					}

					expected = (PRIMARY | LPAREN | FUNCTION | SIGN | NULLARY_CALL);
				}
				else if (this.isRightParenth()) {
				    if (expected & NULLARY_CALL) {
						var token = new Token(TNUMBER, 0, 0, []);
						tokenstack.push(token);
					}
					else if ((expected & RPAREN) === 0) {
						this.error_parsing(this.pos, "unexpected \")\"");
					}

					expected = (OPERATOR | RPAREN | COMMA | LPAREN | CALL);
				}
				else if (this.isComma()) {
					if ((expected & COMMA) === 0) {
						this.error_parsing(this.pos, "unexpected \",\"");
					}
					this.addfunc(tokenstack, operstack, TOP2);
					noperators += 2;
					expected = (PRIMARY | LPAREN | FUNCTION | SIGN);
				}
				else if (this.isConst()) {
					if ((expected & PRIMARY) === 0) {
						this.error_parsing(this.pos, "unexpected constant");
					}
					var consttoken = new Token(TNUMBER, 0, 0, this.tokennumber);
					tokenstack.push(consttoken);
					expected = (OPERATOR | RPAREN | COMMA);
				}
				else if (this.isOp2()) {
					if ((expected & FUNCTION) === 0) {
						this.error_parsing(this.pos, "unexpected function");
					}
					this.addfunc(tokenstack, operstack, TOP2);
					noperators += 2;
					expected = (LPAREN);
				}
				else if (this.isOp1()) {
					if ((expected & FUNCTION) === 0) {
						this.error_parsing(this.pos, "unexpected function");
					}
					this.addfunc(tokenstack, operstack, TOP1);
					noperators++;
					expected = (LPAREN);
				}
				else if (this.isVar()) {
					if ((expected & PRIMARY) === 0) {
						this.error_parsing(this.pos, "unexpected variable");
					}
					var vartoken = new Token(TVAR, this.tokenindex, 0, 0);
					tokenstack.push(vartoken);

					expected = (OPERATOR | RPAREN | COMMA | LPAREN | CALL);
				}
				else if (this.isWhite()) {
				}
				else {
					if (this.errormsg === "") {
						this.error_parsing(this.pos, "unknown character");
					}
					else {
						this.error_parsing(this.pos, this.errormsg);
					}
				}
			}
			if (this.tmpprio < 0 || this.tmpprio >= 10) {
				this.error_parsing(this.pos, "unmatched \"()\"");
			}
			while (operstack.length > 0) {
				var tmp = operstack.pop();
				tokenstack.push(tmp);
			}
			if (noperators + 1 !== tokenstack.length) {
				//print(noperators + 1);
				//print(tokenstack);
				this.error_parsing(this.pos, "parity");
			}

			return new Expression(tokenstack, object(this.ops1), object(this.ops2), object(this.functions));
		},

		evaluate: function (expr, variables) {
			return this.parse(expr).evaluate(variables);
		},

		error_parsing: function (column, msg) {
			this.success = false;
			this.errormsg = "parse error [column " + (column) + "]: " + msg;
			this.column = column;
			throw new Error(this.errormsg);
		},

//\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\

		addfunc: function (tokenstack, operstack, type_) {
			var operator = new Token(type_, this.tokenindex, this.tokenprio + this.tmpprio, 0);
			while (operstack.length > 0) {
				if (operator.prio_ <= operstack[operstack.length - 1].prio_) {
					tokenstack.push(operstack.pop());
				}
				else {
					break;
				}
			}
			operstack.push(operator);
		},

		isNumber: function () {
			var r = false;
			var str = "";
			while (this.pos < this.expression.length) {
				var code = this.expression.charCodeAt(this.pos);
				if ((code >= 48 && code <= 57) || code === 46) {
					str += this.expression.charAt(this.pos);
					this.pos++;
					this.tokennumber = parseFloat(str);
					r = true;
				}
				else {
					break;
				}
			}
			return r;
		},

		// Ported from the yajjl JSON parser at http://code.google.com/p/yajjl/
		unescape: function(v, pos) {
			var buffer = [];
			var escaping = false;

			for (var i = 0; i < v.length; i++) {
				var c = v.charAt(i);

				if (escaping) {
					switch (c) {
					case "'":
						buffer.push("'");
						break;
					case '\\':
						buffer.push('\\');
						break;
					case '/':
						buffer.push('/');
						break;
					case 'b':
						buffer.push('\b');
						break;
					case 'f':
						buffer.push('\f');
						break;
					case 'n':
						buffer.push('\n');
						break;
					case 'r':
						buffer.push('\r');
						break;
					case 't':
						buffer.push('\t');
						break;
					case 'u':
						// interpret the following 4 characters as the hex of the unicode code point
						var codePoint = parseInt(v.substring(i + 1, i + 5), 16);
						buffer.push(String.fromCharCode(codePoint));
						i += 4;
						break;
					default:
						throw this.error_parsing(pos + i, "Illegal escape sequence: '\\" + c + "'");
					}
					escaping = false;
				} else {
					if (c == '\\') {
						escaping = true;
					} else {
						buffer.push(c);
					}
				}
			}

			return buffer.join('');
		},

		isString: function () {
			var r = false;
			var str = "";
			var startpos = this.pos;
			if (this.pos < this.expression.length && this.expression.charAt(this.pos) == "'") {
				this.pos++;
				while (this.pos < this.expression.length) {
					var code = this.expression.charAt(this.pos);
					if (code != "'" || str.slice(-1) == "\\") {
						str += this.expression.charAt(this.pos);
						this.pos++;
					}
					else {
						this.pos++;
						this.tokennumber = this.unescape(str, startpos);
						r = true;
						break;
					}
				}
			}
			return r;
		},

		isConst: function () {
			var str;
			for (var i in this.consts) {
				if (true) {
					var L = i.length;
					str = this.expression.substr(this.pos, L);
					if (i === str) {
						this.tokennumber = this.consts[i];
						this.pos += L;
						return true;
					}
				}
			}
			return false;
		},

		isOperator: function () {
			var code = this.expression.charCodeAt(this.pos);
			if (code === 43) { // +
				this.tokenprio = 2;
				this.tokenindex = "+";
			}
			else if (code === 45) { // -
				this.tokenprio = 2;
				this.tokenindex = "-";
			}
			else if (code === 62) { // >
				if (this.expression.charCodeAt(this.pos + 1) === 61) {
					this.pos++;
					this.tokenprio = 1;
					this.tokenindex = ">=";
				} else {
					this.tokenprio = 1;
					this.tokenindex = ">";
				}
			}
			else if (code === 60) { // <
				if (this.expression.charCodeAt(this.pos + 1) === 61) {
					this.pos++;
					this.tokenprio = 1;
					this.tokenindex = "<=";
				} else {
					this.tokenprio = 1;
					this.tokenindex = "<";
				}
			}
			else if (code === 124) { // |
				if (this.expression.charCodeAt(this.pos + 1) === 124) {
					this.pos++;
					this.tokenprio = 1;
					this.tokenindex = "||";
				}
				else {
					return false;
				}
			}
			else if (code === 61) { // =
				if (this.expression.charCodeAt(this.pos + 1) === 61) {
					this.pos++;
					this.tokenprio = 1;
					this.tokenindex = "==";
				}
				else {
					this.tokenprio = 1;
                    this.tokenindex = "==";
				}
			}
			else if (code === 33) { // !
				if (this.expression.charCodeAt(this.pos + 1) === 61) {
					this.pos++;
					this.tokenprio = 1;
					this.tokenindex = "!=";
				}
				else {
					return false;
				}
			}
			else if (code === 97) { // a
				if (this.expression.charCodeAt(this.pos + 1) === 110 && this.expression.charCodeAt(this.pos + 2) === 100) { // n && d
					this.pos++;
					this.pos++;
					this.tokenprio = 0;
					this.tokenindex = "and";
				}
				else {
					return false;
				}
			}
			else if (code === 111) { // o
				if (this.expression.charCodeAt(this.pos + 1) === 114) { // r
					this.pos++;
					this.tokenprio = 0;
					this.tokenindex = "or";
				}
				else {
					return false;
				}
			}
			else if (code === 42 || code === 8729 || code === 8226) { // * or ∙ or •
				this.tokenprio = 3;
				this.tokenindex = "*";
			}
			else if (code === 47) { // /
				this.tokenprio = 4;
				this.tokenindex = "/";
			}
			else if (code === 37) { // %
				this.tokenprio = 4;
				this.tokenindex = "%";
			}
			else if (code === 94) { // ^
				this.tokenprio = 5;
				this.tokenindex = "^";
			}
			else {
				return false;
			}
			this.pos++;
			return true;
		},

		isSign: function () {
			var code = this.expression.charCodeAt(this.pos - 1);
			if (code === 45 || code === 43) { // -
				return true;
			}
			return false;
		},

		isPositiveSign: function () {
			var code = this.expression.charCodeAt(this.pos - 1);
			if (code === 43) { // +
				return true;
			}
			return false;
		},

		isNegativeSign: function () {
			var code = this.expression.charCodeAt(this.pos - 1);
			if (code === 45) { // -
				return true;
			}
			return false;
		},

		isLeftParenth: function () {
			var code = this.expression.charCodeAt(this.pos);
			if (code === 40) { // (
				this.pos++;
				this.tmpprio += 10;
				return true;
			}
			return false;
		},

		isRightParenth: function () {
			var code = this.expression.charCodeAt(this.pos);
			if (code === 41) { // )
				this.pos++;
				this.tmpprio -= 10;
				return true;
			}
			return false;
		},

		isComma: function () {
			var code = this.expression.charCodeAt(this.pos);
			if (code === 44) { // ,
				this.pos++;
				this.tokenprio = -1;
				this.tokenindex = ",";
				return true;
			}
			return false;
		},

		isWhite: function () {
			var code = this.expression.charCodeAt(this.pos);
			if (code === 32 || code === 9 || code === 10 || code === 13) {
				this.pos++;
				return true;
			}
			return false;
		},

		isOp1: function () {
			var str = "";
			for (var i = this.pos; i < this.expression.length; i++) {
				var c = this.expression.charAt(i);
				if (c.toUpperCase() === c.toLowerCase()) {
					if (i === this.pos || (c != '_' && (c < '0' || c > '9'))) {
						break;
					}
				}
				str += c;
			}
			if (str.length > 0 && (str in this.ops1)) {
				this.tokenindex = str;
				this.tokenprio = 5;
				this.pos += str.length;
				return true;
			}
			return false;
		},

		isOp2: function () {
			var str = "";
			for (var i = this.pos; i < this.expression.length; i++) {
				var c = this.expression.charAt(i);
				if (c.toUpperCase() === c.toLowerCase()) {
					if (i === this.pos || (c != '_' && (c < '0' || c > '9'))) {
						break;
					}
				}
				str += c;
			}
			if (str.length > 0 && (str in this.ops2)) {
				this.tokenindex = str;
				this.tokenprio = 5;
				this.pos += str.length;
				return true;
			}
			return false;
		},

		isVar: function () {
			var str = "";
			for (var i = this.pos; i < this.expression.length; i++) {
				var c = this.expression.charAt(i);
				if (c.toUpperCase() === c.toLowerCase()) {
                    if (i === this.pos && c == '@') {
                        str += c;
                        continue;
                    }
					if (i === this.pos || (c != '_' && c != '.' && (c < '0' || c > '9'))) {
						break;
					}
				}
				str += c;
			}
			if (str.length > 0) {
				this.tokenindex = str;
				this.tokenprio = 4;
				this.pos += str.length;
				return true;
			}
			return false;
		},

		isComment: function () {
			var code = this.expression.charCodeAt(this.pos - 1);
			if (code === 47 && this.expression.charCodeAt(this.pos) === 42) {
				this.pos = this.expression.indexOf("*/", this.pos) + 2;
				if (this.pos === 1) {
					this.pos = this.expression.length;
				}
				return true;
			}
			return false;
		}
	};

	scope.Parser = Parser;
	return Parser
})(typeof exports === 'undefined' ? {} : exports);

},{}],2:[function(require,module,exports){
// Generated by CoffeeScript 1.10.0
(function() {
  var Element, Emitter,
    extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    hasProp = {}.hasOwnProperty,
    slice = [].slice,
    indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  Emitter = require('./emitter');

  Element = (function(superClass) {
    extend(Element, superClass);

    Element.use = function() {
      var ref, res;
      res = (ref = []).concat.apply(ref, arguments).filter(function(x) {
        return x != null;
      }).map((function(_this) {
        return function(elem) {
          var exists;
          exists = Element.prototype.match.call(_this, elem.kind, elem.tag);
          if (exists != null) {
            console.warn(_this.error("use: already loaded '" + elem.kind + "/" + elem.tag + "'"));
            return exists;
          }
          return Element.prototype.merge.call(_this, elem);
        };
      })(this));
      switch (false) {
        case !(res.length > 1):
          return res;
        case res.length !== 1:
          return res[0];
        default:
          return void 0;
      }
    };

    Element.error = function(msg, ctx) {
      var res;
      if (ctx == null) {
        ctx = this;
      }
      res = new Error(msg);
      res.name = 'ElementError';
      res.context = ctx;
      return res;
    };

    function Element(kind, tag, attrs) {
      if (attrs == null) {
        attrs = {};
      }
      if (kind == null) {
        throw this.error("must supply 'kind' to create a new Element");
      }
      if (typeof attrs !== 'object') {
        throw this.error("must supply 'attrs' as an object");
      }
      Element.__super__.constructor.call(this, attrs.parent);
      this.propagate('change');
      Object.defineProperties(this, {
        kind: {
          value: kind,
          enumerable: true
        },
        tag: {
          value: tag,
          enumerable: true,
          writable: true
        },
        node: {
          value: attrs.node === true
        },
        scope: {
          value: attrs.scope,
          writable: true
        },
        trail: {
          get: (function() {
            var node, trail;
            node = this;
            trail = ((function() {
              var ref, results;
              results = [];
              while ((node = node.parent) && node instanceof Element) {
                results.push((ref = node.tag) != null ? ref : node.kind);
              }
              return results;
            })());
            trail = trail.reverse().join('/');
            return trail + "/" + this.kind;
          }).bind(this)
        },
        root: {
          get: (function() {
            if (this.parent instanceof Element) {
              return this.parent.root;
            } else {
              return this;
            }
          }).bind(this)
        },
        elements: {
          get: (function() {
            var k, v;
            return ((function() {
              var results;
              results = [];
              for (k in this) {
                if (!hasProp.call(this, k)) continue;
                v = this[k];
                if (k !== 'tag') {
                  results.push(v);
                }
              }
              return results;
            }).call(this)).reduce((function(a, b) {
              switch (false) {
                case !(b instanceof Element):
                  return a.concat(b);
                case !(b instanceof Array):
                  return a.concat(b.filter(function(x) {
                    return x instanceof Element;
                  }));
                default:
                  return a;
              }
            }), []);
          }).bind(this)
        },
        nodes: {
          get: (function() {
            return this.elements.filter(function(x) {
              return x.node === true;
            });
          }).bind(this)
        },
        attrs: {
          get: (function() {
            return this.elements.filter(function(x) {
              return x.node === false;
            });
          }).bind(this)
        },
        '*': {
          get: (function() {
            return this.nodes;
          }).bind(this)
        },
        '..': {
          get: (function() {
            return this.parent;
          }).bind(this)
        }
      });
    }

    Element.prototype.clone = function() {
      return (new this.constructor(this.kind, this.tag, this))["extends"](this.elements.map(function(x) {
        return x.clone();
      }));
    };

    Element.prototype["extends"] = function() {
      var elems, ref;
      elems = ((ref = []).concat.apply(ref, arguments)).filter(function(x) {
        return (x != null) && !!x;
      });
      if (!(elems.length > 0)) {
        return this;
      }
      elems.forEach((function(_this) {
        return function(expr) {
          return _this.merge(expr);
        };
      })(this));
      this.emit.apply(this, ['change'].concat(slice.call(elems)));
      return this;
    };

    Element.prototype.merge = function(elem) {
      var ref, ref1;
      if (!(elem instanceof Element)) {
        throw this.error("cannot merge a non-Element into an Element", elem);
      }
      if (elem.parent == null) {
        elem.parent = this;
      }
      if (this.scope == null) {
        switch (false) {
          case !!this.hasOwnProperty(elem.kind):
            this[elem.kind] = elem;
            break;
          case this[elem.kind] instanceof Array:
            this[elem.kind] = [this[elem.kind]];
            Object.defineProperty(this[elem.kind], 'tags', {
              value: []
            });
            this[elem.kind].tags.push(elem.tag);
            break;
          case ref = elem.tag, indexOf.call(this[elem.kind].tags, ref) >= 0:
            this[elem.kind].tags.push(elem.tag);
            this[elem.kind].push(elem);
            break;
          default:
            throw this.error("constraint violation for '" + elem.kind + " " + elem.tag + "' - cannot define more than once");
        }
        return elem;
      }
      if (!(elem.kind in this.scope)) {
        if (elem.scope != null) {
          if (typeof this.debug === "function") {
            this.debug(this.scope);
          }
          throw this.error("scope violation - invalid '" + elem.kind + "' extension found");
        } else {
          this.scope[elem.kind] = '*';
        }
      }
      switch (this.scope[elem.kind]) {
        case '0..n':
        case '1..n':
        case '*':
          if (!this.hasOwnProperty(elem.kind)) {
            Object.defineProperty(this, elem.kind, {
              enumerable: true,
              value: []
            });
            Object.defineProperty(this[elem.kind], 'tags', {
              value: []
            });
          }
          if (ref1 = elem.tag, indexOf.call(this[elem.kind].tags, ref1) < 0) {
            this[elem.kind].tags.push(elem.tag);
            this[elem.kind].push(elem);
          } else {
            throw this.error("constraint violation for '" + elem.kind + " " + elem.tag + "' - cannot define more than once");
          }
          break;
        case '0..1':
        case '1':
          if (!this.hasOwnProperty(elem.kind)) {
            Object.defineProperty(this, elem.kind, {
              enumerable: true,
              value: elem
            });
          } else if (elem.kind === 'argument') {
            this[elem.kind] = elem;
          } else {
            throw this.error("constraint violation for '" + elem.kind + "' - cannot define more than once");
          }
          break;
        default:
          throw this.error("unrecognized scope constraint defined for '" + elem.kind + "' with " + this.scope[elem.kind]);
      }
      return elem;
    };

    Element.prototype.update = function(elem) {
      var exists, i, len, ref, target;
      if (!(elem instanceof Element)) {
        throw this.error("cannot update a non-Element into an Element", elem);
      }
      exists = Element.prototype.match.call(this, elem.kind, elem.tag);
      if (exists == null) {
        return this.merge(elem);
      }
      ref = elem.elements;
      for (i = 0, len = ref.length; i < len; i++) {
        target = ref[i];
        exists.update(target);
      }
      return exists;
    };

    Element.prototype.lookup = function(kind, tag) {
      var res;
      res = (function() {
        switch (false) {
          case this instanceof Object:
            return void 0;
          case !(this instanceof Element):
            return this.match(kind, tag);
          default:
            return Element.prototype.match.call(this, kind, tag);
        }
      }).call(this);
      if (res == null) {
        res = (function() {
          switch (false) {
            case this.parent == null:
              return Element.prototype.lookup.apply(this.parent, arguments);
            default:
              return Element.prototype.match.call(this.constructor, kind, tag);
          }
        }).apply(this, arguments);
      }
      return res;
    };

    Element.prototype.locate = function(ypath) {
      var i, key, kind, match, ref, ref1, ref2, ref3, rest, selector, tag;
      if (!(typeof ypath === 'string' && !!ypath)) {
        return;
      }
      if (typeof this.debug === "function") {
        this.debug("locate: " + ypath);
      }
      ypath = ypath.replace(/\s/g, '');
      if ((/^\//.test(ypath)) && this !== this.root) {
        return this.root.locate(ypath);
      }
      ref = ypath.split('/').filter(function(e) {
        return !!e;
      }), key = ref[0], rest = 2 <= ref.length ? slice.call(ref, 1) : [];
      if (key == null) {
        return this;
      }
      switch (false) {
        case key !== '..':
          kind = key;
          break;
        case !/^{.*}$/.test(key):
          kind = 'grouping';
          tag = key.replace(/^{(.*)}$/, '$1');
          break;
        case !/^\[.*\]$/.test(key):
          key = key.replace(/^\[(.*)\]$/, '$1');
          ref1 = key.split(':'), kind = 2 <= ref1.length ? slice.call(ref1, 0, i = ref1.length - 1) : (i = 0, []), tag = ref1[i++];
          ref2 = tag.split('='), tag = ref2[0], selector = ref2[1];
          if (kind != null ? kind.length : void 0) {
            kind = kind[0];
          }
          break;
        default:
          ref3 = key.split('='), tag = ref3[0], selector = ref3[1];
          kind = '*';
      }
      match = this.match(kind, tag);
      switch (false) {
        case rest.length !== 0:
          return match;
        default:
          return match != null ? match.locate(rest.join('/')) : void 0;
      }
    };

    Element.prototype.match = function(kind, tag) {
      var elem, i, key, len, match;
      if (!(this instanceof Object)) {
        return;
      }
      if (!((kind != null) && this.hasOwnProperty(kind))) {
        return;
      }
      if (tag == null) {
        return this[kind];
      }
      match = this[kind];
      if (!(match instanceof Array)) {
        match = [match];
      }
      for (i = 0, len = match.length; i < len; i++) {
        elem = match[i];
        if (!(elem instanceof Element)) {
          continue;
        }
        key = elem.tag != null ? elem.tag : elem.kind;
        if (tag === key) {
          return elem;
        }
      }
      return void 0;
    };

    Element.prototype.error = Element.error;

    Element.prototype.debug = console.debug != null ? function(msg) {
      switch (typeof msg) {
        case 'object':
          return console.debug(msg);
        default:
          return console.debug("[" + this.trail + "] " + msg);
      }
    } : void 0;

    Element.prototype.toObject = function() {
      var obj, sub;
      if (typeof this.debug === "function") {
        this.debug("converting " + this.kind + " toObject with " + this.elements.length);
      }
      sub = this.elements.filter((function(_this) {
        return function(x) {
          return x.parent === _this;
        };
      })(this)).reduce((function(a, b) {
        var k, kk, ref, v, vv;
        ref = b.toObject();
        for (k in ref) {
          v = ref[k];
          if (a[k] instanceof Object) {
            if (v instanceof Object) {
              for (kk in v) {
                vv = v[kk];
                a[k][kk] = vv;
              }
            }
          } else {
            a[k] = v;
          }
        }
        return a;
      }), {});
      return (
        obj = {},
        obj["" + this.kind] = (function() {
          var obj1;
          switch (false) {
            case !(Object.keys(sub).length > 0):
              if (this.tag != null) {
                return (
                  obj1 = {},
                  obj1["" + this.tag] = sub,
                  obj1
                );
              } else {
                return sub;
              }
              break;
            case !(this.tag instanceof Object):
              return "" + this.tag;
            default:
              return this.tag;
          }
        }).call(this),
        obj
      );
    };

    return Element;

  })(Emitter);

  module.exports = Element;

}).call(this);

},{"./emitter":3}],3:[function(require,module,exports){
// Generated by CoffeeScript 1.10.0
(function() {
  var Emitter, events,
    extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    hasProp = {}.hasOwnProperty,
    slice = [].slice;

  events = require('events');

  Emitter = (function(superClass) {
    extend(Emitter, superClass);

    function Emitter(parent) {
      Object.defineProperties(this, {
        parent: {
          value: parent,
          writable: true
        },
        domain: {
          writable: true
        },
        _events: {
          writable: true
        },
        _eventsCount: {
          writable: true
        },
        _maxListeners: {
          writable: true
        }
      });
      Emitter.__super__.constructor.apply(this, arguments);
    }

    Emitter.prototype.propagate = function() {
      var events;
      events = 1 <= arguments.length ? slice.call(arguments, 0) : [];
      return events.forEach((function(_this) {
        return function(event) {
          return _this.on(event, function() {
            var ref, ref1, ref2;
            switch (false) {
              case !(this.parent == null):
                break;
              case !(this.parent instanceof Emitter):
                return (ref = this.parent).emit.apply(ref, [event].concat(slice.call(arguments)));
              case !(this.parent.__ instanceof Emitter):
                return (ref1 = this.parent.__).emit.apply(ref1, [event].concat(slice.call(arguments)));
              default:
                if (typeof console.debug === "function") {
                  console.debug("unable to emit '" + event + "' from " + this.name + " -> parent");
                }
                if (typeof console.debug === "function") {
                  console.debug("parent.emit   = " + (this.parent.emit != null));
                }
                return typeof console.debug === "function" ? console.debug("property.emit = " + (((ref2 = this.parent.__) != null ? ref2.emit : void 0) != null)) : void 0;
            }
          });
        };
      })(this));
    };

    return Emitter;

  })(events.EventEmitter);

  module.exports = Emitter;

}).call(this);

},{"events":17}],4:[function(require,module,exports){
// Generated by CoffeeScript 1.10.0
(function() {
  var Element, Expression,
    extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    hasProp = {}.hasOwnProperty;

  Element = require('./element');

  Expression = (function(superClass) {
    extend(Expression, superClass);

    function Expression(kind, tag, source) {
      var argument, binding, convert, resolved, scope;
      if (source == null) {
        source = {};
      }
      if (!(source instanceof Object)) {
        throw this.error("cannot create new Expression without 'source' object");
      }
      argument = source.argument, binding = source.binding, scope = source.scope, resolved = source.resolved, convert = source.convert;
      if (source.hasOwnProperty('source')) {
        source = source.source;
      }
      if (source.resolve == null) {
        source.resolve = function() {};
      }
      if (source.construct == null) {
        source.construct = function(x) {
          return x;
        };
      }
      if (source.predicate == null) {
        source.predicate = function() {
          return true;
        };
      }
      Expression.__super__.constructor.apply(this, arguments);
      this.scope = scope;
      if (resolved == null) {
        resolved = false;
      }
      Object.defineProperties(this, {
        source: {
          value: source,
          writable: true
        },
        argument: {
          value: argument,
          writable: true
        },
        binding: {
          value: binding,
          writable: true
        },
        resolved: {
          value: resolved,
          writable: true
        },
        convert: {
          value: convert,
          writable: true
        },
        exprs: {
          get: (function() {
            return this.elements.filter(function(x) {
              return x instanceof Expression;
            });
          }).bind(this)
        }
      });
    }

    Expression.prototype.resolve = function() {
      if (typeof this.debug === "function") {
        this.debug("resolve: enter...");
      }
      this.emit('resolve:before', arguments);
      if (this.resolved === false) {
        this.source.resolve.apply(this, arguments);
      }
      if ((this.tag != null) && (this.argument == null)) {
        throw this.error("cannot contain argument '" + this.tag + "' for expression '" + this.kind + "'");
      }
      if ((this.argument != null) && (this.tag == null)) {
        throw this.error("must contain argument '" + this.argument + "' for expression '" + this.kind + "'");
      }
      this.elements.forEach(function(x) {
        return x.resolve.apply(x, arguments);
      });
      this.resolved = true;
      this.emit('resolve:after');
      if (typeof this.debug === "function") {
        this.debug("resolve: ok");
      }
      return this;
    };

    Expression.prototype.bind = function(data) {
      var binding, e, error, key;
      if (!(data instanceof Object)) {
        return;
      }
      if (data instanceof Function) {
        if (typeof this.debug === "function") {
          this.debug("bind: registering function");
        }
        this.binding = data;
        return this;
      }
      for (key in data) {
        binding = data[key];
        try {
          this.locate(key).bind(binding);
        } catch (error) {
          e = error;
          if (e.name === 'ExpressionError') {
            throw e;
          }
          throw this.error("failed to bind to '" + key + "' (schema-path not found)", e);
        }
      }
      return this;
    };

    Expression.prototype.apply = function(data) {
      this.resolve();
      this.emit('apply:before', data);
      data = this.source.construct.call(this, data);
      if (!this.source.predicate.call(this, data)) {
        throw this.error("predicate validation error during apply", data);
      }
      this.emit('apply:after', data);
      return data;
    };

    Expression.prototype["eval"] = function(data, opts) {
      if (opts == null) {
        opts = {};
      }
      if (opts.adaptive == null) {
        opts.adaptive = true;
      }
      data = this.apply(data);
      if (opts.adaptive) {
        this.once('change', arguments.callee.bind(this, data, opts));
      }
      return data;
    };

    Expression.prototype.error = function() {
      var res;
      res = Expression.__super__.error.apply(this, arguments);
      res.name = 'ExpressionError';
      return res;
    };

    return Expression;

  })(Element);

  module.exports = Expression;

}).call(this);

},{"./element":2}],5:[function(require,module,exports){
(function (process){
// Generated by CoffeeScript 1.10.0

/* yang-js
 *
 * The **yang-js** module provides support for basic set of YANG schema
 * modeling language by using the built-in *extension* syntax to define
 * additional schema language constructs.
 *
 */

(function() {
  var Extension, Typedef, Yang, exports;

  if (process.env.yang_debug != null) {
    if (console.debug == null) {
      console.debug = console.log;
    }
  }

  Yang = require('./yang');

  Extension = require('./yang-extension');

  Typedef = require('./yang-typedef');

  Yang.use(Extension.builtins, Typedef.builtins);

  exports = module.exports = Yang;

  exports.Extension = Extension;

  exports.Typedef = Typedef;

  exports.Model = require('./model');

}).call(this);

}).call(this,require('_process'))
},{"./model":6,"./yang":11,"./yang-extension":9,"./yang-typedef":10,"_process":22}],6:[function(require,module,exports){
// Generated by CoffeeScript 1.10.0
(function() {
  var Emitter, Expression, Model, XPath,
    extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    hasProp = {}.hasOwnProperty,
    indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
    slice = [].slice;

  Emitter = require('./emitter');

  XPath = require('./xpath');

  Expression = require('./expression');

  Model = (function(superClass) {
    extend(Model, superClass);

    function Model(schema, props) {
      var k, prop, ref, ref1;
      if (props == null) {
        props = {};
      }
      if (!(schema instanceof Expression)) {
        throw new Error("cannot create a new Model without schema Expression");
      }
      Model.__super__.constructor.apply(this, arguments);
      if (schema.kind !== 'module') {
        schema = (new Expression('module'))["extends"](schema);
      }
      for (k in props) {
        prop = props[k];
        if (ref = prop.schema, indexOf.call(schema.nodes, ref) >= 0) {
          prop.join(this);
        }
      }
      Object.defineProperties(this, {
        '_id': {
          value: (ref1 = schema.tag) != null ? ref1 : Object.keys(this).join('+')
        },
        '__': {
          value: {
            name: schema.tag,
            schema: schema
          }
        }
      });
      Object.preventExtensions(this);
    }

    Model.prototype.on = function() {
      var callback, event, i, xpath;
      event = arguments[0], xpath = 3 <= arguments.length ? slice.call(arguments, 1, i = arguments.length - 1) : (i = 1, []), callback = arguments[i++];
      if (!(xpath.length && (callback != null))) {
        return Model.__super__.on.call(this, event, callback);
      }
      return this.on(event, function() {
        var args, prop, ref;
        prop = arguments[0], args = 2 <= arguments.length ? slice.call(arguments, 1) : [];
        if (ref = prop.path, indexOf.call(xpath, ref) >= 0) {
          return callback.apply(this, [prop].concat(args));
        }
      });
    };

    Model.prototype["in"] = function(uri) {
      var expr, key, keys, li, match, str, xpath;
      if (uri == null) {
        uri = '';
      }
      keys = uri.split('/').filter(function(x) {
        return (x != null) && !!x;
      });
      expr = this.__.schema;
      if (!keys.length) {
        return {
          model: this,
          schema: expr,
          path: XPath.parse('.'),
          match: this
        };
      }
      key = keys.shift();
      expr = (function() {
        switch (false) {
          case expr.tag !== key:
            return expr;
          default:
            return expr.locate(key);
        }
      })();
      str = "/" + key;
      while ((key = keys.shift()) && (expr != null)) {
        if (expr.kind === 'list' && ((expr.locate(key)) == null)) {
          str += "[key() = '" + key + "']";
          key = keys.shift();
          li = true;
          if (key == null) {
            break;
          }
        }
        expr = expr.locate(key);
        if (expr != null) {
          str += "/" + expr.datakey;
        }
      }
      if (keys.length || (expr == null)) {
        return;
      }
      xpath = XPath.parse(str);
      match = xpath.apply(this);
      match = (function() {
        switch (false) {
          case !!(match != null ? match.length : void 0):
            return void 0;
          case !(/list$/.test(expr.kind) && !li):
            return match;
          case !(match.length > 1):
            return match;
          default:
            return match[0];
        }
      })();
      return {
        model: this,
        schema: expr,
        path: xpath,
        match: match,
        key: expr.datakey
      };
    };

    return Model;

  })(Emitter);

  module.exports = Model;

}).call(this);

},{"./emitter":3,"./expression":4,"./xpath":8}],7:[function(require,module,exports){
// Generated by CoffeeScript 1.10.0
(function() {
  var Emitter, Promise, Property, XPath, events,
    extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    hasProp = {}.hasOwnProperty,
    slice = [].slice;

  Promise = require('promise');

  events = require('events');

  XPath = require('./xpath');

  Emitter = require('./emitter');

  Property = (function(superClass) {
    extend(Property, superClass);

    function Property(name, value, opts) {
      if (opts == null) {
        opts = {};
      }
      if (!((name != null) && opts instanceof Object)) {
        console.log(arguments);
        throw new Error("must supply 'name' and 'opts' to create a new Property");
      }
      this.name = name;
      this.configurable = opts.configurable;
      if (this.configurable == null) {
        this.configurable = true;
      }
      this.enumerable = opts.enumerable;
      if (this.enumerable == null) {
        this.enumerable = value != null;
      }
      Property.__super__.constructor.call(this, opts.parent);
      Object.defineProperties(this, {
        schema: {
          value: opts.schema
        },
        path: {
          get: (function() {
            var p, ref, ref1, ref2, x;
            x = this;
            p = [this.name];
            while ((x = (ref1 = x.parent) != null ? ref1.__ : void 0) && ((ref2 = x.schema) != null ? ref2.kind : void 0) !== 'module') {
              if (((ref = x.schema) != null ? ref.kind : void 0) === 'list') {
                if (!(x.content instanceof Array)) {
                  continue;
                }
              }
              p.unshift(x.name);
            }
            return '/' + p.join('/');
          }).bind(this)
        },
        content: {
          get: function() {
            return value;
          },
          set: (function(val) {
            if (val !== value) {
              this.emit('update', this);
            }
            return value = val;
          }).bind(this)
        }
      });
      this.set = this.set.bind(this);
      this.get = this.get.bind(this);
      this.propagate('update', 'create', 'delete');
      if (value instanceof Object) {
        if (!value.hasOwnProperty('__')) {
          Object.defineProperty(value, '__', {
            writable: true
          });
        }
        value.__ = this;
      }
    }

    Property.prototype.join = function(obj) {
      var i, idx, item, len, prev, ref;
      if (!(obj instanceof Object)) {
        return obj;
      }
      this.parent = obj;
      if (!obj.hasOwnProperty('__props__')) {
        Object.defineProperty(obj, '__props__', {
          value: {}
        });
      }
      prev = obj.__props__[this.name];
      obj.__props__[this.name] = this;
      if (typeof console.debug === "function") {
        console.debug("join property '" + this.name + "' into obj");
      }
      if (typeof console.debug === "function") {
        console.debug(obj);
      }
      if (obj instanceof Array && ((ref = this.schema) != null ? ref.kind : void 0) === 'list' && (this.content != null)) {
        for (idx = i = 0, len = obj.length; i < len; idx = ++i) {
          item = obj[idx];
          if (!(item['@key'] === this.content['@key'])) {
            continue;
          }
          if (typeof console.debug === "function") {
            console.debug("found matching key in " + idx);
          }
          obj.splice(idx, 1, this.content);
          return obj;
        }
        obj.push(this.content);
      } else {
        Object.defineProperty(obj, this.name, this);
      }
      this.emit('update', this, prev);
      return obj;
    };

    Property.prototype.set = function(val, force) {
      var obj1, prop, ref, res;
      if (force == null) {
        force = false;
      }
      switch (false) {
        case force !== true:
          return this.content = val;
        case ((ref = this.schema) != null ? ref.apply : void 0) == null:
          if (typeof console.debug === "function") {
            console.debug("setting " + this.name + " with parent: " + (this.parent != null));
          }
          res = this.schema.apply((
            obj1 = {},
            obj1["" + this.name] = val,
            obj1
          ));
          prop = res.__props__[this.name];
          if (this.parent != null) {
            return prop.join(this.parent);
          } else {
            return this.content = prop.content;
          }
          break;
        default:
          return this.content = val;
      }
    };

    Property.prototype.get = function() {
      var desc, k, match, ref;
      switch (false) {
        case !arguments.length:
          match = this.find.apply(this, arguments);
          switch (false) {
            case match.length !== 1:
              return match[0];
            case !(match.length > 1):
              return match;
            default:
              return void 0;
          }
          break;
        case !(this.content instanceof Function):
          switch (false) {
            case this.content.computed !== true:
              return this.content.call(this);
            case this.content.async !== true:
              return (function(_this) {
                return function() {
                  var args;
                  args = 1 <= arguments.length ? slice.call(arguments, 0) : [];
                  return new Promise(function(resolve, reject) {
                    return _this.content.apply(_this, [].concat(args, resolve, reject));
                  });
                };
              })(this);
            default:
              return this.content.bind(this);
          }
          break;
        case !(this.content instanceof Object):
          ref = this.content;
          for (k in ref) {
            if (!hasProp.call(ref, k)) continue;
            if (!(Number.isNaN(Number(k)))) {
              continue;
            }
            desc = Object.getOwnPropertyDescriptor(this.content, k);
            if (desc.writable) {
              delete this.content[k];
            }
          }
          return this.content;
        default:
          return this.content;
      }
    };

    Property.prototype.find = function(xpath) {
      var ref;
      if (!(xpath instanceof XPath)) {
        xpath = new XPath(xpath);
      }
      if (!(this.content instanceof Object)) {
        switch (xpath.tag) {
          case '/':
            return xpath.apply(this.parent);
          case '..':
            return (ref = xpath.xpath) != null ? ref.apply(this.parent) : void 0;
        }
      }
      return xpath.apply(this.content);
    };

    return Property;

  })(Emitter);

  module.exports = Property;

}).call(this);

},{"./emitter":3,"./xpath":8,"events":17,"promise":23}],8:[function(require,module,exports){
// Generated by CoffeeScript 1.10.0
(function() {
  var Expression, Filter, XPath, exports, operator,
    extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    hasProp = {}.hasOwnProperty,
    slice = [].slice;

  operator = require('../ext/parser').Parser;

  Expression = require('./expression');

  Filter = (function(superClass) {
    extend(Filter, superClass);

    function Filter(pattern1) {
      var expr;
      this.pattern = pattern1 != null ? pattern1 : '';
      if (!((Number.isNaN(Number(this.pattern))) || ((Number(this.pattern)) % 1) !== 0)) {
        expr = Number(this.pattern);
      } else {
        expr = operator.parse(this.pattern);
      }
      Filter.__super__.constructor.call(this, 'filter', expr, {
        argument: 'predicate',
        scope: {},
        construct: function(data) {
          if (!(data instanceof Array)) {
            return data;
          }
          if (!(data.length > 0)) {
            return data;
          }
          if (!this.tag) {
            return data;
          }
          data = (function() {
            switch (false) {
              case typeof this.tag !== 'number':
                return [data[this.tag - 1]];
              default:
                return data.filter((function(_this) {
                  return function(elem) {
                    var error;
                    try {
                      return _this.tag.evaluate(_this.tag.variables().reduce((function(a, b) {
                        a[b] = (function() {
                          switch (b) {
                            case 'key':
                              return function() {
                                return elem['@key'];
                              };
                            case 'current':
                              return function() {
                                return elem;
                              };
                            default:
                              return elem[b];
                          }
                        })();
                        return a;
                      }), {}));
                    } catch (error) {
                      return false;
                    }
                  };
                })(this));
            }
          }).call(this);
          return data;
        }
      });
    }

    Filter.prototype.toString = function() {
      return this.pattern;
    };

    return Filter;

  })(Expression);

  XPath = (function(superClass) {
    extend(XPath, superClass);

    function XPath(pattern) {
      var elements, predicates, ref, target;
      if (typeof pattern !== 'string') {
        throw this.error("must pass in 'pattern' as valid string");
      }
      elements = pattern.match(/([^\/^\[]+(?:\[.+?\])*)/g);
      if (!((elements != null) && elements.length > 0)) {
        throw this.error("unable to process '" + pattern + "' (please check your input)");
      }
      if (/^\//.test(pattern)) {
        target = '/';
        predicates = [];
      } else {
        ref = elements.shift().split(/\[\s*(.+?)\s*\]/), target = ref[0], predicates = 2 <= ref.length ? slice.call(ref, 1) : [];
        predicates = predicates.filter(function(x) {
          return !!x;
        });
      }
      XPath.__super__.constructor.call(this, 'xpath', target, {
        argument: 'node',
        scope: {
          filter: '0..n',
          xpath: '0..1'
        },
        construct: function(data) {
          var expr, i, key, len, prop, ref1, ref2;
          if (!(data instanceof Object)) {
            return data;
          }
          if (this.tag === '/') {
            while (((ref1 = data.__) != null ? ref1.parent : void 0) != null) {
              data = data.__.parent;
            }
            key = '.';
          } else {
            key = this.tag;
          }
          if (!(data instanceof Array)) {
            prop = data.__;
            data = [data];
          }
          data = data.reduce((function(a, b) {
            if (!(b instanceof Array)) {
              prop = b.__;
              b = [b];
            }
            return a.concat.apply(a, b.map(function(elem) {
              var expr, k, kw, match, prefix, res, v;
              if (key === '.') {
                return elem;
              }
              if (!(elem instanceof Object)) {
                return;
              }
              res = (function() {
                var ref2, ref3, ref4, results;
                switch (false) {
                  case key !== '..':
                    return (ref2 = elem.__) != null ? ref2.parent : void 0;
                  case key !== '*':
                    results = [];
                    for (k in elem) {
                      if (!hasProp.call(elem, k)) continue;
                      v = elem[k];
                      results.push(v);
                    }
                    return results;
                  case !elem.hasOwnProperty(key):
                    return elem[key];
                  case !(/.+?:.+/.test(key) && (((ref3 = elem.__) != null ? ref3.schema : void 0) != null)):
                    expr = elem.__.schema;
                    match = expr.locate(key);
                    if ((match != null ? match.parent : void 0) === expr) {
                      return elem[match.datakey];
                    } else {
                      return elem[key];
                    }
                    break;
                  default:
                    for (k in elem) {
                      if (!hasProp.call(elem, k)) continue;
                      if (!(/.+?:.+/.test(k))) {
                        continue;
                      }
                      ref4 = k.split(':'), prefix = ref4[0], kw = ref4[1];
                      if (kw === key) {
                        match = elem[k];
                        break;
                      }
                    }
                    return match;
                }
              })();
              if ((res != null ? res.__ : void 0) != null) {
                prop = res.__;
              }
              return res;
            }));
          }), []);
          data = data.filter(function(e) {
            return e != null;
          });
          ref2 = this.exprs;
          for (i = 0, len = ref2.length; i < len; i++) {
            expr = ref2[i];
            if (!((data != null) && data.length > 0)) {
              break;
            }
            data = expr.apply(data);
          }
          if (!data.hasOwnProperty('__')) {
            Object.defineProperty(data, '__', {
              value: prop
            });
          }
          return data;
        }
      });
      if (predicates.length > 0) {
        this["extends"].apply(this, predicates.map(function(x) {
          return new Filter(x);
        }));
      }
      if (elements.length > 0) {
        this["extends"](new XPath(elements.join('/')));
      }
    }

    XPath.prototype.toString = function() {
      var filter, i, len, ref, s;
      s = this.tag === '/' ? '' : this.tag;
      if (this.filter != null) {
        ref = this.filter;
        for (i = 0, len = ref.length; i < len; i++) {
          filter = ref[i];
          s += "[" + filter + "]";
        }
      }
      if (this.xpath != null) {
        s += "/" + this.xpath;
      }
      return s;
    };

    return XPath;

  })(Expression);

  exports = module.exports = XPath;

  exports.parse = function(pattern) {
    return new XPath(pattern);
  };

}).call(this);

},{"../ext/parser":1,"./expression":4}],9:[function(require,module,exports){
// Generated by CoffeeScript 1.10.0
(function() {
  var Expression, Extension, Property, XPath, Yang, exports,
    extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    hasProp = {}.hasOwnProperty,
    slice = [].slice;

  Expression = require('./expression');

  Yang = require('./yang');

  Property = require('./property');

  XPath = require('./xpath');

  Extension = (function(superClass) {
    extend(Extension, superClass);

    Extension.scope = {
      argument: '0..1',
      description: '0..1',
      reference: '0..1',
      status: '0..1'
    };

    function Extension(name, spec) {
      if (spec == null) {
        spec = {};
      }
      if (!(spec instanceof Object)) {
        throw this.error("must supply 'spec' as object");
      }
      if (spec.scope == null) {
        spec.scope = {};
      }
      Extension.__super__.constructor.call(this, 'extension', name, spec);
      Object.defineProperties(this, {
        argument: {
          value: spec.argument
        },
        compose: {
          value: spec.compose
        }
      });
    }

    return Extension;

  })(Expression);

  exports = module.exports = Extension;

  exports.builtins = [
    new Extension('action', {
      argument: 'name',
      node: true,
      scope: {
        description: '0..1',
        grouping: '0..n',
        'if-feature': '0..n',
        input: '0..1',
        output: '0..1',
        reference: '0..1',
        status: '0..1',
        typedef: '0..n'
      },
      construct: function(data) {
        var expr, func, i, len, ref, ref1, ref2;
        if (data == null) {
          data = {};
        }
        if (!(data instanceof Object)) {
          return data;
        }
        func = (ref = (ref1 = data[this.tag]) != null ? ref1 : this.binding) != null ? ref : (function(_this) {
          return function(a, b, c) {
            throw _this.error("handler function undefined");
          };
        })(this);
        if (!(func instanceof Function)) {
          throw this.error("expected a function but got a '" + (typeof func) + "'");
        }
        if (func.length !== 3) {
          throw this.error("cannot define without function (input, resolve, reject)");
        }
        ref2 = this.exprs;
        for (i = 0, len = ref2.length; i < len; i++) {
          expr = ref2[i];
          func = expr.apply(func);
        }
        func.async = true;
        return (new Property(this.tag, func, {
          schema: this
        })).join(data);
      },
      compose: function(data, opts) {
        if (opts == null) {
          opts = {};
        }
        if (!(data instanceof Function)) {
          return;
        }
        if (Object.keys(data).length !== 0) {
          return;
        }
        if (Object.keys(data.prototype).length !== 0) {
          return;
        }
        return (new Yang(this.tag, opts.tag, this)).bind(data);
      }
    }), new Extension('anydata', {
      argument: 'name',
      scope: {
        config: '0..1',
        description: '0..1',
        'if-feature': '0..n',
        mandatory: '0..1',
        must: '0..n',
        reference: '0..1',
        status: '0..1',
        when: '0..1'
      }
    }), new Extension('argument', {
      argument: 'arg-type',
      scope: {
        'yin-element': '0..1'
      }
    }), new Extension('augment', {
      argument: 'target-node',
      scope: {
        action: '0..n',
        anydata: '0..n',
        anyxml: '0..n',
        "case": '0..n',
        choice: '0..n',
        container: '0..n',
        description: '0..1',
        'if-feature': '0..n',
        leaf: '0..n',
        'leaf-list': '0..n',
        list: '0..n',
        notification: '0..n',
        reference: '0..1',
        status: '0..1',
        uses: '0..n',
        when: '0..1'
      },
      resolve: function() {
        var target;
        target = (function() {
          switch (this.parent.kind) {
            case 'module':
              if (!/^\//.test(this.tag)) {
                throw this.error("'" + this.tag + "' must be absolute-schema-path");
              }
              return this.locate(this.tag);
            case 'uses':
              if (/^\//.test(this.tag)) {
                throw this.error("'" + this.tag + "' must be relative-schema-path");
              }
              return this.parent.grouping.locate(this.tag);
          }
        }).call(this);
        if (target == null) {
          console.warn(this.error("unable to locate '" + this.tag + "'"));
          return;
        }
        if (this.when == null) {
          if (typeof this.debug === "function") {
            this.debug("augmenting '" + target.kind + ":" + target.tag + "'");
          }
          return target["extends"](this.exprs.filter(function(x) {
            var ref;
            return (ref = x.kind) !== 'description' && ref !== 'reference' && ref !== 'status';
          }));
        } else {
          return target.on('apply:after', (function(_this) {
            return function(data) {
              var expr, i, len, ref, results;
              if (data != null) {
                ref = _this.exprs;
                results = [];
                for (i = 0, len = ref.length; i < len; i++) {
                  expr = ref[i];
                  results.push(data = expr.apply(data));
                }
                return results;
              }
            };
          })(this));
        }
      }
    }), new Extension('base', {
      argument: 'name'
    }), new Extension('belongs-to', {
      argument: 'module-name',
      scope: {
        prefix: '1'
      },
      resolve: function() {
        this.module = this.lookup('module', this.tag);
        if (this.module == null) {
          throw this.error("unable to resolve '" + this.tag + "' module");
        }
      }
    }), new Extension('bit', {
      argument: 'name',
      scope: {
        description: '0..1',
        reference: '0..1',
        status: '0..1',
        position: '0..1'
      }
    }), new Extension('case', {
      argument: 'name',
      scope: {
        anyxml: '0..n',
        choice: '0..n',
        container: '0..n',
        description: '0..1',
        'if-feature': '0..n',
        leaf: '0..n',
        'leaf-list': '0..n',
        list: '0..n',
        reference: '0..1',
        status: '0..1',
        uses: '0..n',
        when: '0..1'
      }
    }), new Extension('choice', {
      argument: 'condition',
      scope: {
        anyxml: '0..n',
        "case": '0..n',
        config: '0..1',
        container: '0..n',
        "default": '0..1',
        description: '0..1',
        'if-feature': '0..n',
        leaf: '0..n',
        'leaf-list': '0..n',
        list: '0..n',
        mandatory: '0..1',
        reference: '0..1',
        status: '0..1',
        when: '0..1'
      }
    }), new Extension('config', {
      argument: 'value',
      resolve: function() {
        return this.tag = this.tag === true || this.tag === 'true';
      },
      construct: function(data) {
        var func;
        if (data == null) {
          return;
        }
        if (this.tag === true && !(data instanceof Function)) {
          return data;
        }
        if (!(data instanceof Function)) {
          throw this.error("cannot set data on read-only element");
        }
        func = function() {
          var expr, i, len, ref, v;
          v = data.call(this);
          ref = this.schema.exprs;
          for (i = 0, len = ref.length; i < len; i++) {
            expr = ref[i];
            if (expr.kind !== 'config') {
              v = expr.apply(v);
            }
          }
          return v;
        };
        func.computed = true;
        return func;
      },
      predicate: function(data) {
        return (data == null) || this.tag === true || data instanceof Function;
      }
    }), new Extension('contact', {
      argument: 'text',
      yin: true
    }), new Extension('container', {
      argument: 'name',
      node: true,
      scope: {
        action: '0..n',
        anydata: '0..n',
        anyxml: '0..n',
        choice: '0..n',
        config: '0..1',
        container: '0..n',
        description: '0..1',
        grouping: '0..n',
        'if-feature': '0..n',
        leaf: '0..n',
        'leaf-list': '0..n',
        list: '0..n',
        must: '0..n',
        notification: '0..n',
        presence: '0..1',
        reference: '0..1',
        status: '0..1',
        typedef: '0..n',
        uses: '0..n',
        when: '0..1'
      },
      construct: function(data) {
        var expr, i, len, obj, ref, ref1;
        if (data == null) {
          data = {};
        }
        if (!(data instanceof Object)) {
          return data;
        }
        obj = (ref = data[this.datakey]) != null ? ref : this.binding;
        if (obj != null) {
          ref1 = this.exprs;
          for (i = 0, len = ref1.length; i < len; i++) {
            expr = ref1[i];
            obj = expr.apply(obj);
          }
        }
        return (new Property(this.datakey, obj, {
          schema: this
        })).join(data);
      },
      predicate: function(data) {
        return ((data != null ? data[this.datakey] : void 0) == null) || data[this.datakey] instanceof Object;
      },
      compose: function(data, opts) {
        var expr, i, k, kind, len, match, matches, possibilities, ref, v;
        if (opts == null) {
          opts = {};
        }
        if ((data != null ? data.constructor : void 0) !== Object) {
          return;
        }
        possibilities = (function() {
          var ref, results;
          ref = this.scope;
          results = [];
          for (kind in ref) {
            if (!hasProp.call(ref, kind)) continue;
            results.push(this.lookup('extension', kind));
          }
          return results;
        }).call(this);
        matches = [];
        for (k in data) {
          if (!hasProp.call(data, k)) continue;
          v = data[k];
          for (i = 0, len = possibilities.length; i < len; i++) {
            expr = possibilities[i];
            if (!(expr != null)) {
              continue;
            }
            if (typeof this.debug === "function") {
              this.debug("checking '" + k + "' to see if " + expr.tag);
            }
            match = typeof expr.compose === "function" ? expr.compose(v, {
              tag: k
            }) : void 0;
            if (match != null) {
              break;
            }
          }
          if (match == null) {
            return;
          }
          matches.push(match);
        }
        return (ref = new Yang(this.tag, opts.tag, this))["extends"].apply(ref, matches);
      }
    }), new Extension('default', {
      argument: 'value',
      construct: function(data) {
        return data != null ? data : this.tag;
      }
    }), new Extension('description', {
      argument: 'text',
      yin: true
    }), new Extension('deviate', {
      argument: 'value',
      scope: {
        config: '0..1',
        "default": '0..1',
        mandatory: '0..1',
        'max-elements': '0..1',
        'min-elements': '0..1',
        must: '0..n',
        type: '0..1',
        unique: '0..1',
        units: '0..1'
      }
    }), new Extension('deviation', {
      argument: 'target-node',
      scope: {
        description: '0..1',
        deviate: '1..n',
        reference: '0..1'
      }
    }), new Extension('enum', {
      argument: 'name',
      scope: {
        description: '0..1',
        reference: '0..1',
        status: '0..1',
        value: '0..1'
      },
      resolve: function() {
        var base, cval;
        if ((base = this.parent).enumValue == null) {
          base.enumValue = 0;
        }
        if (this.value == null) {
          return this["extends"](this.constructor.parse("value " + (this.parent.enumValue++) + ";"));
        } else {
          cval = (Number(this.value.tag)) + 1;
          if (!(this.parent.enumValue > cval)) {
            return this.parent.enumValue = cval;
          }
        }
      }
    }), new Extension('error-app-tag', {
      argument: 'value'
    }), new Extension('error-message', {
      argument: 'value',
      yin: true
    }), new Extension('extension', {
      argument: 'extension-name',
      scope: {
        argument: '0..1',
        description: '0..1',
        reference: '0..1',
        status: '0..1'
      },
      resolve: function() {}
    }), new Extension('feature', {
      argument: 'name',
      scope: {
        description: '0..1',
        'if-feature': '0..n',
        reference: '0..1',
        status: '0..1'
      },
      resolve: function() {
        var ref;
        if (((ref = this.status) != null ? ref.tag : void 0) === 'unavailable') {
          return console.warn("feature " + this.tag + " is unavailable");
        }
      },
      compose: function(data, opts) {
        var ref;
        if (opts == null) {
          opts = {};
        }
        if ((data != null ? data.constructor : void 0) === Object) {
          return;
        }
        if (!(data instanceof Object)) {
          return;
        }
        if (data instanceof Function && Object.keys(data.prototype).length === 0) {
          return;
        }
        return (new Yang(this.tag, (ref = opts.tag) != null ? ref : data.name)).bind(data);
      }
    }), new Extension('fraction-digits', {
      argument: 'value'
    }), new Extension('grouping', {
      argument: 'name',
      scope: {
        action: '0..n',
        anydata: '0..n',
        anyxml: '0..n',
        choice: '0..n',
        container: '0..n',
        description: '0..1',
        grouping: '0..n',
        leaf: '0..n',
        'leaf-list': '0..n',
        list: '0..n',
        notification: '0..n',
        reference: '0..1',
        status: '0..1',
        typedef: '0..n',
        uses: '0..n'
      }
    }), new Extension('identity', {
      argument: 'name',
      scope: {
        base: '0..1',
        description: '0..1',
        reference: '0..1',
        status: '0..1'
      },
      resolve: function() {
        if (this.base != null) {
          return this.lookup('identity', this.base.tag);
        }
      }
    }), new Extension('if-feature', {
      argument: 'feature-name',
      resolve: function() {
        if ((this.lookup('feature', this.tag)) == null) {
          return console.warn("should be turned off...");
        }
      }
    }), new Extension('import', {
      argument: 'module',
      scope: {
        prefix: '1',
        'revision-date': '0..1'
      },
      resolve: function() {
        var module, ref, rev;
        module = this.lookup('module', this.tag);
        if (module == null) {
          throw this.error("unable to resolve '" + this.tag + "' module");
        }
        Object.defineProperty(this, 'module', {
          value: module
        });
        rev = (ref = this['revision-date']) != null ? ref.tag : void 0;
        if ((rev != null) && ((this.module.match('revision', rev)) == null)) {
          throw this.error("requested " + rev + " not available in " + this.tag);
        }
      }
    }), new Extension('include', {
      argument: 'module',
      scope: {
        'revision-date': '0..1'
      },
      resolve: function() {
        var i, len, m, ref, results, x;
        m = this.lookup('submodule', this.tag);
        if (m == null) {
          throw this.error("unable to resolve '" + this.tag + "' submodule");
        }
        if (this.parent.tag !== m['belongs-to'].tag) {
          throw m.error("requested submodule '" + this.tag + "' not belongs-to '" + this.parent.tag + "'");
        }
        m['belongs-to'].module = this.parent;
        ref = m.elements;
        results = [];
        for (i = 0, len = ref.length; i < len; i++) {
          x = ref[i];
          if (m.scope[x.kind] === '0..n' && x.kind !== 'revision') {
            results.push((this.parent.update(x)).resolve());
          }
        }
        return results;
      }
    }), new Extension('input', {
      scope: {
        anyxml: '0..n',
        choice: '0..n',
        container: '0..n',
        grouping: '0..n',
        leaf: '0..n',
        'leaf-list': '0..n',
        list: '0..n',
        typedef: '0..n',
        uses: '0..n'
      },
      construct: function(func) {
        if (!(func instanceof Function)) {
          throw this.error("expected a function but got a '" + (typeof func) + "'");
        }
        return function(input, resolve, reject) {
          var e, error, expr, i, len, ref;
          try {
            ref = this.schema.input.exprs;
            for (i = 0, len = ref.length; i < len; i++) {
              expr = ref[i];
              input = expr.apply(input);
            }
          } catch (error) {
            e = error;
            reject(e);
          }
          return func.call(this, input, resolve, reject);
        };
      }
    }), new Extension('key', {
      argument: 'value',
      resolve: function() {
        return this.parent.once('resolve:after', (function(_this) {
          return function() {
            _this.tag = _this.tag.split(' ');
            if (!(_this.tag.every(function(k) {
              return _this.parent.match('leaf', k) != null;
            }))) {
              throw _this.error("unable to reference key items as leaf elements", _this.parent);
            }
          };
        })(this));
      },
      construct: function(data) {
        var exists, i, item, key, len, list;
        if (!(data instanceof Object)) {
          return data;
        }
        list = data;
        if (!(list instanceof Array)) {
          list = [list];
        }
        exists = {};
        for (i = 0, len = list.length; i < len; i++) {
          item = list[i];
          if (!(item instanceof Object)) {
            continue;
          }
          if (!item.hasOwnProperty('@key')) {
            Object.defineProperty(item, '@key', {
              get: (function() {
                if (typeof this.debug === "function") {
                  this.debug("GETTING @key from " + this + " using " + this.tag + ":");
                }
                return (this.tag.map(function(k) {
                  return item[k];
                })).join(',');
              }).bind(this)
            });
          }
          key = item['@key'];
          if (exists[key] === true) {
            throw this.error("key conflict for " + key);
          }
          exists[key] = true;
          if (data instanceof Array) {
            if (typeof this.debug === "function") {
              this.debug("defining a direct key mapping for '" + key + "'");
            }
            if (Number(key)) {
              key = "__" + key + "__";
            }
            (new Property(key, item, {
              schema: this,
              enumerable: false
            })).join(data);
          }
        }
        return data;
      },
      predicate: function(data) {
        if (data instanceof Array) {
          return true;
        }
        return this.tag.every((function(_this) {
          return function(k) {
            return data[k] != null;
          };
        })(this));
      }
    }), new Extension('leaf', {
      argument: 'name',
      node: true,
      scope: {
        config: '0..1',
        "default": '0..1',
        description: '0..1',
        'if-feature': '0..n',
        mandatory: '0..1',
        must: '0..n',
        reference: '0..1',
        status: '0..1',
        type: '0..1',
        units: '0..1',
        when: '0..1'
      },
      resolve: function() {
        var ref;
        if (((ref = this.mandatory) != null ? ref.tag : void 0) === 'true' && (this["default"] != null)) {
          throw this.error("cannot define 'default' when 'mandatory' is true");
        }
      },
      construct: function(data) {
        var expr, i, len, ref, ref1, val;
        if (data == null) {
          data = {};
        }
        if ((data != null ? data.constructor : void 0) !== Object) {
          return data;
        }
        val = (ref = data[this.datakey]) != null ? ref : this.binding;
        if (typeof console.debug === "function") {
          console.debug("expr on leaf " + this.tag + " for " + val + " with " + this.exprs.length + " exprs");
        }
        ref1 = this.exprs;
        for (i = 0, len = ref1.length; i < len; i++) {
          expr = ref1[i];
          if (expr.kind !== 'type') {
            val = expr.apply(val);
          }
        }
        if (this.type != null) {
          val = this.type.apply(val);
        }
        return (new Property(this.datakey, val, {
          schema: this
        })).join(data);
      },
      compose: function(data, opts) {
        var ref, type;
        if (opts == null) {
          opts = {};
        }
        if (data instanceof Array) {
          return;
        }
        if (data instanceof Object && Object.keys(data).length > 0) {
          return;
        }
        type = (ref = this.lookup('extension', 'type')) != null ? typeof ref.compose === "function" ? ref.compose(data) : void 0 : void 0;
        if (type == null) {
          return;
        }
        if (typeof this.debug === "function") {
          this.debug("leaf " + opts.tag + " found " + (type != null ? type.tag : void 0));
        }
        return (new Yang(this.tag, opts.tag, this))["extends"](type);
      }
    }), new Extension('leaf-list', {
      argument: 'name',
      node: true,
      scope: {
        config: '0..1',
        description: '0..1',
        'if-feature': '0..n',
        'max-elements': '0..1',
        'min-elements': '0..1',
        must: '0..n',
        'ordered-by': '0..1',
        reference: '0..1',
        status: '0..1',
        type: '0..1',
        units: '0..1',
        when: '0..1'
      },
      construct: function(data) {
        var expr, i, len, ll, ref, ref1;
        if (data == null) {
          data = {};
        }
        if (!(data instanceof Object)) {
          return data;
        }
        ll = (ref = data[this.tag]) != null ? ref : this.binding;
        if (ll != null) {
          ref1 = this.exprs;
          for (i = 0, len = ref1.length; i < len; i++) {
            expr = ref1[i];
            ll = expr.apply(ll);
          }
        }
        return (new Property(this.tag, ll, {
          schema: this
        })).join(data);
      },
      predicate: function(data) {
        return (data[this.tag] == null) || data[this.tag] instanceof Array;
      },
      compose: function(data, opts) {
        var type_, types;
        if (opts == null) {
          opts = {};
        }
        if (!(data instanceof Array)) {
          return;
        }
        if (!data.every(function(x) {
          return typeof x !== 'object';
        })) {
          return;
        }
        type_ = this.lookup('extension', 'type');
        types = data.map(function(x) {
          return typeof type_.compose === "function" ? type_.compose(x) : void 0;
        });
        return (new Yang(this.tag, opts.tag, this))["extends"](types[0]);
      }
    }), new Extension('length', {
      argument: 'value',
      scope: {
        description: '0..1',
        'error-app-tag': '0..1',
        'error-message': '0..1',
        reference: '0..1'
      }
    }), new Extension('list', {
      argument: 'name',
      node: true,
      scope: {
        action: '0..n',
        anydata: '0..n',
        anyxml: '0..n',
        choice: '0..n',
        config: '0..1',
        container: '0..n',
        description: '0..1',
        grouping: '0..n',
        'if-feature': '0..n',
        key: '0..1',
        leaf: '0..n',
        'leaf-list': '0..n',
        list: '0..n',
        'max-elements': '0..1',
        'min-elements': '0..1',
        must: '0..n',
        notification: '0..n',
        'ordered-by': '0..1',
        reference: '0..1',
        status: '0..1',
        typedef: '0..n',
        unique: '0..1',
        uses: '0..n',
        when: '0..1'
      },
      construct: function(data) {
        var expr, i, len, list, ref, ref1;
        if (data == null) {
          data = {};
        }
        if (!(data instanceof Object)) {
          return data;
        }
        list = (ref = data[this.datakey]) != null ? ref : this.binding;
        if (list instanceof Array) {
          list = list.map((function(_this) {
            return function(li, idx) {
              var expr, i, len, ref1;
              if (!(li instanceof Object)) {
                throw _this.error("list item entry must be an object");
              }
              ref1 = _this.exprs;
              for (i = 0, len = ref1.length; i < len; i++) {
                expr = ref1[i];
                li = expr.apply(li);
              }
              return li;
            };
          })(this));
        }
        if (typeof this.debug === "function") {
          this.debug("processing list " + this.datakey + " with " + this.exprs.length);
        }
        if (list != null) {
          ref1 = this.exprs;
          for (i = 0, len = ref1.length; i < len; i++) {
            expr = ref1[i];
            list = expr.apply(list);
          }
        }
        if (list instanceof Array) {
          list.forEach((function(_this) {
            return function(li, idx, self) {
              return new Property(_this.datakey, li, {
                schema: _this,
                parent: self
              });
            };
          })(this));
          Object.defineProperties(list, {
            add: {
              value: function() {
                var item, items, j, len1, ref2;
                items = 1 <= arguments.length ? slice.call(arguments, 0) : [];
                for (j = 0, len1 = items.length; j < len1; j++) {
                  item = items[j];
                  if ((item != null ? item.__ : void 0) instanceof Property) {
                    item.__.parent = this;
                  }
                }
                this.push.apply(this, items);
                (ref2 = this.__).emit.apply(ref2, ['create', this.__].concat(slice.call(items)));
                return this.__.emit('update', this.__);
              }
            },
            remove: {
              value: function(key) {
                var idx, item, items, ref2;
                console.log("remove " + key + " from list with " + this.length + " entries");
                items = [];
                for (idx in this) {
                  item = this[idx];
                  if (!(item['@key'] === key)) {
                    continue;
                  }
                  this.splice(idx, 1);
                  items.push(item);
                }
                (ref2 = this.__).emit.apply(ref2, ['delete', this.__].concat(slice.call(items)));
                return this.__.emit('update', this.__);
              }
            }
          });
        }
        return (new Property(this.datakey, list, {
          schema: this
        })).join(data);
      },
      predicate: function(data) {
        return (data[this.datakey] == null) || data[this.datakey] instanceof Object;
      },
      compose: function(data, opts) {
        var expr, i, k, kind, len, match, matches, possibilities, ref, v;
        if (opts == null) {
          opts = {};
        }
        if (!(data instanceof Array && data.length > 0)) {
          return;
        }
        if (!data.every(function(x) {
          return typeof x === 'object';
        })) {
          return;
        }
        data = data[0];
        possibilities = (function() {
          var ref, results;
          ref = this.scope;
          results = [];
          for (kind in ref) {
            if (!hasProp.call(ref, kind)) continue;
            results.push(this.lookup('extension', kind));
          }
          return results;
        }).call(this);
        matches = [];
        for (k in data) {
          if (!hasProp.call(data, k)) continue;
          v = data[k];
          for (i = 0, len = possibilities.length; i < len; i++) {
            expr = possibilities[i];
            if (!(expr != null)) {
              continue;
            }
            match = typeof expr.compose === "function" ? expr.compose(v, {
              tag: k
            }) : void 0;
            if (match != null) {
              break;
            }
          }
          if (match == null) {
            return;
          }
          matches.push(match);
        }
        return (ref = new Yang(this.tag, opts.tag, this))["extends"].apply(ref, matches);
      }
    }), new Extension('mandatory', {
      argument: 'value',
      resolve: function() {
        return this.tag = this.tag === true || this.tag === 'true';
      },
      predicate: function(data) {
        return this.tag !== true || (data != null);
      }
    }), new Extension('max-elements', {
      argument: 'value',
      resolve: function() {
        if (this.tag !== 'unbounded') {
          return this.tag = Number(this.tag);
        }
      },
      predicate: function(data) {
        return this.tag === 'unbounded' || !(data instanceof Array) || data.length <= this.tag;
      }
    }), new Extension('min-elements', {
      argument: 'value',
      resolve: function() {
        return this.tag = Number(this.tag);
      },
      predicate: function(data) {
        return !(data instanceof Array) || data.length >= this.tag;
      }
    }), new Extension('modifier', {
      argument: 'value',
      resolve: function() {
        return this.tag = this.tag === 'invert-match';
      }
    }), new Extension('module', {
      argument: 'name',
      node: true,
      scope: {
        anydata: '0..n',
        anyxml: '0..n',
        augment: '0..n',
        choice: '0..n',
        contact: '0..1',
        container: '0..n',
        description: '0..1',
        deviation: '0..n',
        extension: '0..n',
        feature: '0..n',
        grouping: '0..n',
        identity: '0..n',
        "import": '0..n',
        include: '0..n',
        leaf: '0..n',
        'leaf-list': '0..n',
        list: '0..n',
        namespace: '0..1',
        notification: '0..n',
        organization: '0..1',
        prefix: '0..1',
        reference: '0..1',
        revision: '0..n',
        rpc: '0..n',
        typedef: '0..n',
        uses: '0..n',
        'yang-version': '0..1'
      },
      resolve: function() {
        var ref, ref1;
        if (((ref = this['yang-version']) != null ? ref.tag : void 0) === '1.1') {
          if (!((this.namespace != null) && (this.prefix != null))) {
            throw this.error("must define 'namespace' and 'prefix' for YANG 1.1 compliance");
          }
        }
        if (((ref1 = this.extension) != null ? ref1.length : void 0) > 0) {
          return typeof this.debug === "function" ? this.debug("found " + this.extension.length + " new extension(s)") : void 0;
        }
      },
      construct: function(data) {
        var expr, i, len, ref;
        if (data == null) {
          data = {};
        }
        if (!(data instanceof Object)) {
          return data;
        }
        ref = this.exprs;
        for (i = 0, len = ref.length; i < len; i++) {
          expr = ref[i];
          data = expr.apply(data);
        }
        return data;
      },
      compose: function(data, opts) {
        var expr, i, k, kind, len, match, matches, possibilities, ref, v;
        if (opts == null) {
          opts = {};
        }
        if (!(data instanceof Object)) {
          return;
        }
        if (data instanceof Function && Object.keys(data).length === 0) {
          return;
        }
        possibilities = (function() {
          var ref, results;
          ref = this.scope;
          results = [];
          for (kind in ref) {
            if (!hasProp.call(ref, kind)) continue;
            results.push(this.lookup('extension', kind));
          }
          return results;
        }).call(this);
        matches = [];
        for (k in data) {
          if (!hasProp.call(data, k)) continue;
          v = data[k];
          for (i = 0, len = possibilities.length; i < len; i++) {
            expr = possibilities[i];
            if (!(expr != null)) {
              continue;
            }
            if (typeof this.debug === "function") {
              this.debug("checking '" + k + "' to see if " + expr.tag);
            }
            match = typeof expr.compose === "function" ? expr.compose(v, {
              tag: k
            }) : void 0;
            if (match != null) {
              break;
            }
          }
          if (match == null) {
            console.log("unable to find match for " + k);
            console.log(v);
          }
          if (match == null) {
            return;
          }
          matches.push(match);
        }
        return (ref = new Yang(this.tag, opts.tag, this))["extends"].apply(ref, matches);
      }
    }), new Extension('must', {
      argument: 'condition',
      scope: {
        description: '0..1',
        'error-app-tag': '0..1',
        'error-message': '0..1',
        reference: '0..1'
      }
    }), new Extension('namespace', {
      argument: 'uri'
    }), new Extension('notification', {
      argument: 'event',
      scope: {
        anydata: '0..n',
        anyxml: '0..n',
        choice: '0..n',
        container: '0..n',
        description: '0..1',
        grouping: '0..n',
        'if-feature': '0..n',
        leaf: '0..n',
        'leaf-list': '0..n',
        list: '0..n',
        reference: '0..1',
        status: '0..1',
        typedef: '0..n',
        uses: '0..n'
      },
      construct: function() {}
    }), new Extension('ordered-by', {
      argument: 'value'
    }), new Extension('organization', {
      argument: 'text',
      yin: true
    }), new Extension('output', {
      scope: {
        anyxml: '0..n',
        choice: '0..n',
        container: '0..n',
        grouping: '0..n',
        leaf: '0..n',
        'leaf-list': '0..n',
        list: '0..n',
        typedef: '0..n',
        uses: '0..n'
      },
      construct: function(func) {
        if (!(func instanceof Function)) {
          throw this.error("expected a function but got a '" + (typeof func) + "'");
        }
        return function(input, resolve, reject) {
          return func.apply(this, [
            input, (function(_this) {
              return function(res) {
                var e, error, expr, i, len, ref;
                try {
                  ref = _this.schema.output.exprs;
                  for (i = 0, len = ref.length; i < len; i++) {
                    expr = ref[i];
                    res = expr.apply(res);
                  }
                } catch (error) {
                  e = error;
                  reject(e);
                }
                return resolve(res);
              };
            })(this), reject
          ]);
        };
      }
    }), new Extension('path', {
      argument: 'value',
      resolve: function() {
        return this.tag = new XPath(this.tag);
      }
    }), new Extension('pattern', {
      argument: 'value',
      scope: {
        description: '0..1',
        'error-app-tag': '0..1',
        'error-message': '0..1',
        modifier: '0..1',
        reference: '0..1'
      },
      resolve: function() {
        return this.tag = new RegExp(this.tag);
      }
    }), new Extension('position', {
      argument: 'value'
    }), new Extension('prefix', {
      argument: 'value',
      resolve: function() {}
    }), new Extension('presence', {
      argument: 'value'
    }), new Extension('range', {
      argument: 'value',
      scope: {
        description: '0..1',
        'error-app-tag': '0..1',
        'error-message': '0..1',
        reference: '0..1'
      }
    }), new Extension('reference', {
      argument: 'value'
    }), new Extension('refine', {
      argument: 'target-node',
      scope: {
        "default": '0..1',
        description: '0..1',
        reference: '0..1',
        config: '0..1',
        mandatory: '0..1',
        presence: '0..1',
        must: '0..n',
        'min-elements': '0..1',
        'max-elements': '0..1',
        units: '0..1'
      },
      resolve: function() {
        var target;
        target = this.parent.grouping.locate(this.tag);
        if (target == null) {
          console.warn(this.error("unable to locate '" + this.tag + "'"));
          return;
        }
        if (typeof this.debug === "function") {
          this.debug("APPLY " + this + " to " + target);
        }
        return this.exprs.forEach(function(expr) {
          var ref;
          switch (false) {
            case !target.hasOwnProperty(expr.kind):
              if ((ref = expr.kind) === 'must' || ref === 'if-feature') {
                return target["extends"](expr);
              } else {
                return target[expr.kind] = expr;
              }
              break;
            default:
              return target["extends"](expr);
          }
        });
      }
    }), new Extension('require-instance', {
      argument: 'value',
      resolve: function() {
        return this.tag = this.tag === true || this.tag === 'true';
      }
    }), new Extension('revision', {
      argument: 'date',
      scope: {
        description: '0..1',
        reference: '0..1'
      }
    }), new Extension('revision-date', {
      argument: 'date'
    }), new Extension('rpc', {
      argument: 'name',
      node: true,
      scope: {
        description: '0..1',
        grouping: '0..n',
        'if-feature': '0..n',
        input: '0..1',
        output: '0..1',
        reference: '0..1',
        status: '0..1',
        typedef: '0..n'
      },
      construct: function(data) {
        var expr, i, len, ref, ref1, ref2, rpc;
        if (data == null) {
          data = {};
        }
        if (!(data instanceof Object)) {
          return data;
        }
        rpc = (ref = (ref1 = data[this.tag]) != null ? ref1 : this.binding) != null ? ref : (function(_this) {
          return function(a, b, c) {
            throw _this.error("handler function undefined");
          };
        })(this);
        if (!(rpc instanceof Function)) {
          throw this.error("expected a function but got a '" + (typeof func) + "'");
        }
        if (rpc.length !== 3) {
          throw this.error("cannot define without function (input, resolve, reject)");
        }
        ref2 = this.exprs;
        for (i = 0, len = ref2.length; i < len; i++) {
          expr = ref2[i];
          rpc = expr.apply(rpc);
        }
        rpc.async = true;
        return (new Property(this.tag, rpc, {
          schema: this
        })).join(data);
      },
      compose: function(data, opts) {
        if (opts == null) {
          opts = {};
        }
        if (!(data instanceof Function)) {
          return;
        }
        if (Object.keys(data).length !== 0) {
          return;
        }
        if (Object.keys(data.prototype).length !== 0) {
          return;
        }
        return (new Yang(this.tag, opts.tag, this)).bind(data);
      }
    }), new Extension('status', {
      argument: 'value',
      resolve: function() {
        var ref;
        return this.tag = (ref = this.tag) != null ? ref : 'current';
      }
    }), new Extension('submodule', {
      argument: 'name',
      scope: {
        anyxml: '0..n',
        augment: '0..n',
        'belongs-to': '0..1',
        choice: '0..n',
        contact: '0..1',
        container: '0..n',
        description: '0..1',
        deviation: '0..n',
        extension: '0..n',
        feature: '0..n',
        grouping: '0..n',
        identity: '0..n',
        "import": '0..n',
        include: '0..n',
        leaf: '0..n',
        'leaf-list': '0..n',
        list: '0..n',
        notification: '0..n',
        organization: '0..1',
        reference: '0..1',
        revision: '0..n',
        rpc: '0..n',
        typedef: '0..n',
        uses: '0..n',
        'yang-version': '0..1'
      }
    }), new Extension('type', {
      argument: 'name',
      scope: {
        base: '0..1',
        bit: '0..n',
        "enum": '0..n',
        'fraction-digits': '0..1',
        length: '0..1',
        path: '0..1',
        pattern: '0..n',
        range: '0..1',
        'require-instance': '0..1',
        type: '0..n'
      },
      resolve: function() {
        var expr, i, len, ref, ref1, typedef;
        typedef = this.lookup('typedef', this.tag);
        if (typedef == null) {
          console.log(this.parent);
          throw this.error("unable to resolve typedef for " + this.tag);
        }
        if (typedef.type != null) {
          ref = typedef.type.exprs;
          for (i = 0, len = ref.length; i < len; i++) {
            expr = ref[i];
            this.update(expr);
          }
        }
        this.convert = (ref1 = typedef.convert) != null ? ref1.bind(this) : void 0;
        if ((this.parent != null) && this.parent.kind !== 'type') {
          try {
            return this.parent["extends"](typedef["default"], typedef.units);
          } catch (undefined) {}
        }
      },
      construct: function(data) {
        switch (false) {
          case !(data instanceof Function):
            return data;
          case !(data instanceof Array):
            return data.map((function(_this) {
              return function(x) {
                return _this.convert(x);
              };
            })(this));
          default:
            return this.convert(data);
        }
      },
      compose: function(data, opts) {
        var e, error, i, len, typedef, typedefs;
        if (opts == null) {
          opts = {};
        }
        if (data instanceof Function) {
          return;
        }
        typedefs = this.lookup('typedef');
        for (i = 0, len = typedefs.length; i < len; i++) {
          typedef = typedefs[i];
          if (typeof this.debug === "function") {
            this.debug("checking if '" + data + "' is " + typedef.tag);
          }
          try {
            if ((typedef.convert(data)) !== void 0) {
              break;
            }
          } catch (error) {
            e = error;
            if (typeof this.debug === "function") {
              this.debug(e);
            }
          }
        }
        if (typedef == null) {
          return;
        }
        return new Yang(this.tag, typedef.tag);
      }
    }), new Extension('typedef', {
      argument: 'name',
      scope: {
        "default": '0..1',
        description: '0..1',
        units: '0..1',
        type: '0..1',
        reference: '0..1',
        status: '0..1'
      },
      resolve: function() {
        var builtin;
        if (this.type != null) {
          this.convert = this.type.resolve().convert;
          return;
        }
        builtin = this.lookup('typedef', this.tag);
        if (builtin == null) {
          throw this.error("unable to resolve '" + this.tag + "' built-in type");
        }
        return this.convert = builtin.convert;
      }
    }), new Extension('unique', {
      argument: 'tag',
      resolve: function() {
        this.tag = this.tag.split(' ');
        if (!(this.tag.every((function(_this) {
          return function(k) {
            return _this.parent.match('leaf', k) != null;
          };
        })(this)))) {
          throw this.error("referenced unique items do not have leaf elements");
        }
      },
      predicate: function(data) {
        var seen;
        if (!(data instanceof Array)) {
          return true;
        }
        seen = {};
        return data.every((function(_this) {
          return function(item) {
            var key;
            key = _this.tag.reduce((function(a, b) {
              return a += item[b];
            }), '');
            if (seen[key]) {
              return false;
            }
            seen[key] = true;
            return true;
          };
        })(this));
      }
    }), new Extension('units', {
      argument: 'value'
    }), new Extension('uses', {
      argument: 'grouping-name',
      scope: {
        augment: '0..n',
        description: '0..1',
        'if-feature': '0..n',
        refine: '0..n',
        reference: '0..1',
        status: '0..1',
        when: '0..1'
      },
      resolve: function() {
        var grouping;
        grouping = this.lookup('grouping', this.tag);
        if (grouping == null) {
          throw this.error("unable to resolve " + this.tag + " grouping definition");
        }
        Object.defineProperty(this, 'grouping', {
          value: grouping.clone()
        });
        if (this.when == null) {
          if (typeof this.debug === "function") {
            this.debug("extending " + this.grouping + " into " + this.parent);
          }
          return this.parent["extends"](this.grouping.elements.filter(function(x) {
            var ref;
            return (ref = x.kind) !== 'description' && ref !== 'reference' && ref !== 'status';
          }));
        } else {
          return this.parent.on('apply:after', (function(_this) {
            return function(data) {
              var expr, i, len, ref, results;
              if (data != null) {
                ref = _this.grouping.exprs;
                results = [];
                for (i = 0, len = ref.length; i < len; i++) {
                  expr = ref[i];
                  results.push(data = expr.apply(data));
                }
                return results;
              }
            };
          })(this));
        }
      }
    }), new Extension('value', {
      argument: 'value'
    }), new Extension('when', {
      argument: 'condition',
      scope: {
        description: '0..1',
        reference: '0..1'
      }
    }), new Extension('yang-version', {
      argument: 'value'
    }), new Extension('yin-element', {
      argument: 'value'
    })
  ];

}).call(this);

},{"./expression":4,"./property":7,"./xpath":8,"./yang":11}],10:[function(require,module,exports){
// Generated by CoffeeScript 1.10.0
(function() {
  var Element, Integer, Typedef, exports,
    extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    hasProp = {}.hasOwnProperty,
    indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  Element = require('./element');

  Typedef = (function(superClass) {
    extend(Typedef, superClass);

    function Typedef(name, spec) {
      var ref;
      if (spec == null) {
        spec = {};
      }
      if (!(spec instanceof Object)) {
        throw this.error("must supply 'spec' as object");
      }
      Typedef.__super__.constructor.call(this, 'typedef', name);
      Object.defineProperties(this, {
        convert: {
          value: (ref = spec.construct) != null ? ref : function(x) {
            return x;
          }
        },
        schema: {
          value: spec.schema
        }
      });
    }

    return Typedef;

  })(Element);

  Integer = (function(superClass) {
    extend(Integer, superClass);

    function Integer(name, range) {
      Integer.__super__.constructor.call(this, name, {
        construct: function(value) {
          var ranges;
          if (value == null) {
            return;
          }
          if ((Number.isNaN(Number(value))) || ((Number(value)) % 1) !== 0) {
            throw new Error("[" + this.tag + "] unable to convert '" + value + "'");
          }
          if (typeof value === 'string' && !value) {
            throw new Error("[" + this.tag + "] unable to convert '" + value + "'");
          }
          if (this.range != null) {
            range = this.range.tag;
          }
          if (range != null) {
            ranges = range.split('|');
            ranges = ranges.map(function(e) {
              var max, min, ref;
              ref = e.split(/\s*\.\.\s*/), min = ref[0], max = ref[1];
              min = Number(min);
              max = (function() {
                switch (false) {
                  case max !== 'max':
                    return null;
                  default:
                    return Number(max);
                }
              })();
              return function(v) {
                return ((min == null) || v >= min) && ((max == null) || v <= max);
              };
            });
          }
          value = Number(value);
          if (!((ranges == null) || ranges.some(function(test) {
            return typeof test === "function" ? test(value) : void 0;
          }))) {
            throw new Error("[" + this.tag + "] range violation for '" + value + "' on " + this.range.tag);
          }
          return value;
        }
      });
    }

    return Integer;

  })(Typedef);

  exports = module.exports = Typedef;

  exports.builtins = [
    new Typedef('boolean', {
      construct: function(value) {
        if (value == null) {
          return;
        }
        switch (false) {
          case typeof value !== 'string':
            if (value !== 'true' && value !== 'false') {
              throw new Error("[" + this.tag + "] " + value + " must be 'true' or 'false'");
            }
            return value === 'true';
          case typeof value !== 'boolean':
            return value;
          default:
            throw new Error("[" + this.tag + "] unable to convert '" + value + "'");
        }
      }
    }), new Typedef('empty', {
      construct: function(value) {
        if (value != null) {
          throw new Error("[" + this.tag + "] cannot contain value");
        }
        return null;
      }
    }), new Typedef('binary', {
      construct: function(value) {
        if (value == null) {
          return;
        }
        if (!(value instanceof Object)) {
          throw new Error("[" + this.tag + "] unable to convert '" + value + "'");
        }
        return value;
      }
    }), new Integer('int8', '-128..127'), new Integer('int16', '-32768..32767'), new Integer('int32', '-2147483648..2147483647'), new Integer('int64', '-9223372036854775808..9223372036854775807'), new Integer('uint8', '0..255'), new Integer('uint16', '0..65535'), new Integer('uint32', '0..4294967295'), new Integer('uint64', '0..18446744073709551615'), new Typedef('decimal64', {
      construct: function(value) {
        if (value == null) {
          return;
        }
        if (Number.isNaN(Number(value))) {
          throw new Error("[" + this.tag + "] unable to convert '" + value + "'");
        }
        if (typeof value === 'string' && !value) {
          throw new Error("[" + this.tag + "] unable to convert '" + value + "'");
        }
        switch (false) {
          case typeof value !== 'string':
            return Number(value);
          case typeof value !== 'number':
            return value;
          default:
            throw new Error("[" + this.tag + "] type violation for " + value);
        }
      }
    }), new Typedef('string', {
      construct: function(value) {
        var patterns, ranges, ref;
        if (value == null) {
          return;
        }
        patterns = (ref = this.pattern) != null ? ref.map(function(x) {
          return x.tag;
        }) : void 0;
        if (this.length != null) {
          ranges = this.length.tag.split('|');
          ranges = ranges.map(function(e) {
            var max, min, ref1;
            ref1 = e.split(/\s*\.\.\s*/), min = ref1[0], max = ref1[1];
            min = Number(min);
            max = (function() {
              switch (false) {
                case max !== 'max':
                  return null;
                default:
                  return Number(max);
              }
            })();
            return function(v) {
              return ((min == null) || v.length >= min) && ((max == null) || v.length <= max);
            };
          });
        }
        value = String(value);
        if (!((ranges == null) || ranges.some(function(test) {
          return typeof test === "function" ? test(value) : void 0;
        }))) {
          throw new Error("[" + this.tag + "] length violation for '" + value + "' on " + this.length.tag);
        }
        if (!((patterns == null) || patterns.every(function(regex) {
          return regex.test(value);
        }))) {
          throw new Error("[" + this.tag + "] pattern violation for '" + value + "'");
        }
        return value;
      }
    }), new Typedef('union', {
      construct: function(value) {
        var error, j, len, ref, type;
        if (this.type == null) {
          throw new Error("[" + this.tag + "] must contain one or more type definitions");
        }
        ref = this.type;
        for (j = 0, len = ref.length; j < len; j++) {
          type = ref[j];
          try {
            return type.convert(value);
          } catch (error) {
            continue;
          }
        }
        throw new Error("[" + this.tag + "] unable to find matching type for '" + value + "' within: " + this.type);
      }
    }), new Typedef('enumeration', {
      construct: function(value) {
        var i, j, len, ref, ref1;
        if (value == null) {
          return;
        }
        if (!(((ref = this["enum"]) != null ? ref.length : void 0) > 0)) {
          throw new Error("[" + this.tag + "] must have one or more 'enum' definitions");
        }
        ref1 = this["enum"];
        for (j = 0, len = ref1.length; j < len; j++) {
          i = ref1[j];
          if (value === i.tag) {
            return i.tag;
          }
          if (value === i.value.tag) {
            return i.tag;
          }
          if (("" + value) === i.value.tag) {
            return i.tag;
          }
        }
        throw new Error("[" + this.tag + "] type violation for '" + value + "' on " + (this["enum"].map(function(x) {
          return x.tag;
        })));
      }
    }), new Typedef('identityref', {
      construct: function(value) {
        var base, imports, j, len, m, match, ref;
        if (value == null) {
          return;
        }
        if (!((this.base != null) && typeof this.base.tag === 'string')) {
          throw new Error("[" + this.tag + "] must reference 'base' identity");
        }
        base = this.base.tag;
        if (!((this.base != null) && typeof this.base.tag === 'string')) {
          throw new Error("[" + this.tag + "] must reference 'base' identity");
        }
        return value;
        base = this.base.tag;
        match = origin.lookup('identity', value);
        if (match == null) {
          imports = (ref = origin.lookup('import')) != null ? ref : [];
          for (j = 0, len = imports.length; j < len; j++) {
            m = imports[j];
            match = m.module.lookup('identity', value);
            if (match != null) {
              break;
            }
          }
        }
        if (typeof console.debug === "function") {
          console.debug("base: " + base + " match: " + match + " value: " + value);
        }
        return value;
      }
    }), new Typedef('instance-identifier', {
      construct: function(value) {
        if (value == null) {
          return;
        }
        if (!((typeof value === 'string') && /([^\/^\[]+(?:\[.+\])*)/.test(value))) {
          throw new Error("[" + this.tag + "] unable to convert " + value + " into valid XPATH expression");
        }
        return value;
      }
    }), new Typedef('leafref', {
      construct: function(value) {
        var func, xpath;
        if (value == null) {
          return;
        }
        if (this.path == null) {
          throw new Error("[" + this.tag + "] must contain 'path' statement");
        }
        xpath = this.path.tag;
        func = function() {
          var err, res, valid;
          res = this.get(xpath);
          valid = (function() {
            switch (false) {
              case !(res instanceof Array):
                return indexOf.call(res, value) >= 0;
              default:
                return res === value;
            }
          })();
          if (valid !== true) {
            err = new Error("[" + this.tag + "] " + this.name + " is invalid for '" + value + "' (not found in " + xpath + ")");
            err['error-tag'] = 'data-missing';
            err['error-app-tag'] = 'instance-required';
            err['err-path'] = xpath;
            return err;
          } else {
            return value;
          }
        };
        func.computed = true;
        return func;
      }
    })
  ];

}).call(this);

},{"./element":2}],11:[function(require,module,exports){
// Generated by CoffeeScript 1.10.0
(function() {
  var Expression, Model, Yang, clone, fs, indent, parser, path,
    extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    hasProp = {}.hasOwnProperty,
    slice = [].slice;

  

  path = require('path');

  parser = require('yang-parser');

  indent = require('indent-string');

  clone = require('clone');

  Expression = require('./expression');

  Model = require('./model');

  Yang = (function(superClass) {
    extend(Yang, superClass);

    Yang.scope = {
      extension: '0..n',
      typedef: '0..n',
      module: '0..n',
      submodule: '0..n'
    };

    Yang.parse = function(schema, resolve) {
      var constraint, e, error, kind, offender, ref, tag;
      if (resolve == null) {
        resolve = true;
      }
      try {
        if (typeof schema === 'string') {
          schema = parser.parse(schema);
        }
      } catch (error) {
        e = error;
        if (!(e.offset > 50)) {
          e.offset = 50;
        }
        offender = schema.slice(e.offset - 50, e.offset + 50);
        offender = offender.replace(/\s\s+/g, ' ');
        throw this.error("invalid YANG syntax detected", offender);
      }
      if (!(schema instanceof Object)) {
        throw this.error("must pass in valid YANG schema", schema);
      }
      kind = (function() {
        switch (false) {
          case !schema.prf:
            return schema.prf + ":" + schema.kw;
          default:
            return schema.kw;
        }
      })();
      if (!!schema.arg) {
        tag = schema.arg;
      }
      schema = (new this(kind, tag))["extends"](schema.substmts.map((function(_this) {
        return function(x) {
          return _this.parse(x, false);
        };
      })(this)));
      ref = schema.scope;
      for (kind in ref) {
        constraint = ref[kind];
        if (constraint === '1' || constraint === '1..n') {
          if (!schema.hasOwnProperty(kind)) {
            throw schema.error("constraint violation for required '" + kind + "' = " + constraint);
          }
        }
      }
      if (resolve !== false) {
        schema.resolve(resolve);
      }
      return schema;
    };

    Yang.compose = function(data, opts) {
      var ext, i, len, ref, res;
      if (opts == null) {
        opts = {};
      }
      if (opts.kind != null) {
        ext = Yang.prototype.lookup.call(this, 'extension', opts.kind);
        if (!(ext instanceof Expression)) {
          throw new Error("unable to find requested '" + opts.kind + "' extension");
        }
        return typeof ext.compose === "function" ? ext.compose(data, opts) : void 0;
      }
      ref = this.extension;
      for (i = 0, len = ref.length; i < len; i++) {
        ext = ref[i];
        if (!(ext.compose instanceof Function)) {
          continue;
        }
        if (typeof console.debug === "function") {
          console.debug("checking data if " + ext.tag);
        }
        res = ext.compose(data, opts);
        if (res instanceof Yang) {
          return res;
        }
      }
    };

    Yang.resolve = function() {
      var dir, file, found, from, i, name;
      from = 2 <= arguments.length ? slice.call(arguments, 0, i = arguments.length - 1) : (i = 0, []), name = arguments[i++];
      if (typeof name !== 'string') {
        return null;
      }
      dir = from = (function() {
        switch (false) {
          case !from.length:
            return from[0];
          default:
            return path.resolve();
        }
      })();
      while ((found == null) && (dir !== '/' && dir !== '.')) {
        if (typeof console.debug === "function") {
          console.debug("resolving " + name + " in " + dir + "/package.json");
        }
        try {
          found = require(dir + "/package.json").models[name];
          dir = path.dirname(require.resolve(dir + "/package.json"));
        } catch (undefined) {}
        if (found == null) {
          dir = path.dirname(dir);
        }
      }
      file = (function() {
        switch (false) {
          case !((found != null) && /^[\.\/]/.test(found)):
            return path.resolve(dir, found);
          case found == null:
            return this.resolve(found, name);
        }
      }).call(this);
      if (file == null) {
        file = path.resolve(from, name + ".yang");
      }
      if (typeof console.debug === "function") {
        console.debug("checking if " + file + " exists");
      }
      if (fs.existsSync(file)) {
        return file;
      } else {
        return null;
      }
    };

    Yang.require = function(name, opts) {
      var basedir, dependency, e, error, extname, filename, ref, ref1;
      if (opts == null) {
        opts = {};
      }
      if (name == null) {
        return;
      }
      if (opts.basedir == null) {
        opts.basedir = '';
      }
      if (opts.resolve == null) {
        opts.resolve = true;
      }
      extname = path.extname(name);
      filename = path.resolve(opts.basedir, name);
      basedir = path.dirname(filename);
      if (!extname) {
        return (ref = Yang.prototype.match.call(this, 'module', name)) != null ? ref : this.require(this.resolve(name), opts);
      }
      if (extname !== '.yang') {
        return require(filename);
      }
      try {
        return this.use(this.parse(fs.readFileSync(filename, 'utf-8'), opts.resolve));
      } catch (error) {
        e = error;
        if (!(opts.resolve && e.name === 'ExpressionError' && ((ref1 = e.context.kind) === 'include' || ref1 === 'import'))) {
          console.error("unable to require YANG module from '" + filename + "'");
          console.error(e);
          throw e;
        }
        if (e.context.kind === 'include') {
          opts.resolve = false;
        }
        dependency = this.require(this.resolve(basedir, e.context.tag), opts);
        if (dependency == null) {
          e.message = "unable to auto-resolve '" + e.context.tag + "' dependency module";
          throw e;
        }
        if (typeof console.debug === "function") {
          console.debug("retrying require(" + name + ")");
        }
        return this.require.apply(this, arguments);
      }
    };

    Yang.register = function(opts) {
      var ref;
      if (opts == null) {
        opts = {};
      }
      if ((ref = require.extensions) != null) {
        if (ref['.yang'] == null) {
          ref['.yang'] = function(m, filename) {
            return m.exports = Yang.require(filename, opts);
          };
        }
      }
      return exports;
    };

    function Yang(kind, tag, extension) {
      if (this.constructor !== Yang) {
        return (function() {
          return this["eval"].apply(this, arguments);
        }).bind(Yang.parse(arguments[0], true));
      }
      if (extension == null) {
        extension = this.lookup('extension', kind);
      }
      if (!(extension instanceof Expression)) {
        this.once('resolve:before', (function(_this) {
          return function() {
            extension = _this.lookup('extension', kind);
            if (!(extension instanceof Yang)) {
              throw _this.error("encountered unknown extension '" + kind + "'");
            }
            return _this.source = extension.source, _this.argument = extension.argument, extension;
          };
        })(this));
      }
      Yang.__super__.constructor.call(this, kind, tag, extension);
      Object.defineProperties(this, {
        datakey: {
          get: (function() {
            switch (false) {
              case !(this.parent instanceof Yang && this.parent.kind === 'module'):
                return this.parent.tag + ":" + this.tag;
              default:
                return this.tag;
            }
          }).bind(this)
        }
      });
    }

    Yang.prototype.error = function(msg, context) {
      return Yang.__super__.error.call(this, this.trail + "[" + this.tag + "] " + msg, context);
    };

    Yang.prototype["eval"] = function(data, opts) {
      if (this.node !== true) {
        return Yang.__super__["eval"].apply(this, arguments);
      }
      if (data instanceof Model) {
        return data;
      }
      data = Yang.__super__["eval"].call(this, clone(data), opts);
      return new Model(this, data.__props__);
    };

    Yang.prototype.locate = function(ypath) {
      var i, key, len, m, match, prefix, ref, ref1, ref2, ref3, ref4, rest, skey, target;
      if (!(typeof ypath === 'string' && !!ypath)) {
        return;
      }
      ypath = ypath.replace(/\s/g, '');
      if ((/^\//.test(ypath)) && this !== this.root) {
        return this.root.locate(ypath);
      }
      ref = ypath.split('/').filter(function(e) {
        return !!e;
      }), key = ref[0], rest = 2 <= ref.length ? slice.call(ref, 1) : [];
      if (key == null) {
        return this;
      }
      if (key === '..') {
        return (ref1 = this.parent) != null ? ref1.locate(rest.join('/')) : void 0;
      }
      match = key.match(/^([\._-\w]+):([\._-\w]+)$/);
      if (match == null) {
        return Yang.__super__.locate.apply(this, arguments);
      }
      ref2 = [match[1], match[2]], prefix = ref2[0], target = ref2[1];
      if (typeof this.debug === "function") {
        this.debug("looking for '" + prefix + ":" + target + "'");
      }
      rest = rest.map(function(x) {
        return x.replace(prefix + ":", '');
      });
      skey = [target].concat(rest).join('/');
      if ((this.tag === prefix) || (this.lookup('prefix', prefix))) {
        if (typeof this.debug === "function") {
          this.debug("(local) locate '" + skey + "'");
        }
        return Yang.__super__.locate.call(this, skey);
      }
      ref4 = (ref3 = this["import"]) != null ? ref3 : [];
      for (i = 0, len = ref4.length; i < len; i++) {
        m = ref4[i];
        if (!(m.prefix.tag === prefix)) {
          continue;
        }
        if (typeof this.debug === "function") {
          this.debug("(external) locate " + skey);
        }
        return m.module.locate(skey);
      }
      return void 0;
    };

    Yang.prototype.match = function(kind, tag) {
      var arg, ctx, i, imports, j, len, m, prefix, ref, ref1, ref2, ref3, ref4;
      if (!((kind != null) && (tag != null) && typeof tag === 'string')) {
        return Yang.__super__.match.apply(this, arguments);
      }
      ref = tag.split(':'), prefix = 2 <= ref.length ? slice.call(ref, 0, i = ref.length - 1) : (i = 0, []), arg = ref[i++];
      if (!prefix.length) {
        return Yang.__super__.match.apply(this, arguments);
      }
      prefix = prefix[0];
      if (((ref1 = this.root) != null ? (ref2 = ref1.prefix) != null ? ref2.tag : void 0 : void 0) === prefix) {
        return this.root.match(kind, arg);
      }
      ctx = this.lookup('belongs-to');
      if ((ctx != null ? ctx.prefix.tag : void 0) === prefix) {
        return ctx.module.match(kind, arg);
      }
      imports = (ref3 = (ref4 = this.root) != null ? ref4["import"] : void 0) != null ? ref3 : [];
      for (j = 0, len = imports.length; j < len; j++) {
        m = imports[j];
        if (m.prefix.tag === prefix) {
          return m.module.match(kind, arg);
        }
      }
    };

    Yang.prototype.toString = function(opts) {
      var s, sub;
      if (opts == null) {
        opts = {
          space: 2
        };
      }
      s = this.kind;
      if (this.source.argument != null) {
        s += ' ' + (function() {
          switch (this.source.argument) {
            case 'value':
              return "'" + this.tag + "'";
            case 'text':
              return "\n" + (indent('"' + this.tag + '"', ' ', opts.space));
            default:
              return this.tag;
          }
        }).call(this);
      }
      sub = this.elements.filter((function(_this) {
        return function(x) {
          return x.parent === _this;
        };
      })(this)).map(function(x) {
        return x.toString(opts);
      }).join("\n");
      if (!!sub) {
        s += " {\n" + (indent(sub, ' ', opts.space)) + "\n}";
      } else {
        s += ';';
      }
      return s;
    };

    return Yang;

  })(Expression);

  module.exports = Yang;

}).call(this);

},{"./expression":4,"./model":6,"clone":15,"indent-string":18,"path":21,"yang-parser":32}],12:[function(require,module,exports){
"use strict";

// rawAsap provides everything we need except exception management.
var rawAsap = require("./raw");
// RawTasks are recycled to reduce GC churn.
var freeTasks = [];
// We queue errors to ensure they are thrown in right order (FIFO).
// Array-as-queue is good enough here, since we are just dealing with exceptions.
var pendingErrors = [];
var requestErrorThrow = rawAsap.makeRequestCallFromTimer(throwFirstError);

function throwFirstError() {
    if (pendingErrors.length) {
        throw pendingErrors.shift();
    }
}

/**
 * Calls a task as soon as possible after returning, in its own event, with priority
 * over other events like animation, reflow, and repaint. An error thrown from an
 * event will not interrupt, nor even substantially slow down the processing of
 * other events, but will be rather postponed to a lower priority event.
 * @param {{call}} task A callable object, typically a function that takes no
 * arguments.
 */
module.exports = asap;
function asap(task) {
    var rawTask;
    if (freeTasks.length) {
        rawTask = freeTasks.pop();
    } else {
        rawTask = new RawTask();
    }
    rawTask.task = task;
    rawAsap(rawTask);
}

// We wrap tasks with recyclable task objects.  A task object implements
// `call`, just like a function.
function RawTask() {
    this.task = null;
}

// The sole purpose of wrapping the task is to catch the exception and recycle
// the task object after its single use.
RawTask.prototype.call = function () {
    try {
        this.task.call();
    } catch (error) {
        if (asap.onerror) {
            // This hook exists purely for testing purposes.
            // Its name will be periodically randomized to break any code that
            // depends on its existence.
            asap.onerror(error);
        } else {
            // In a web browser, exceptions are not fatal. However, to avoid
            // slowing down the queue of pending tasks, we rethrow the error in a
            // lower priority turn.
            pendingErrors.push(error);
            requestErrorThrow();
        }
    } finally {
        this.task = null;
        freeTasks[freeTasks.length] = this;
    }
};

},{"./raw":13}],13:[function(require,module,exports){
(function (global){
"use strict";

// Use the fastest means possible to execute a task in its own turn, with
// priority over other events including IO, animation, reflow, and redraw
// events in browsers.
//
// An exception thrown by a task will permanently interrupt the processing of
// subsequent tasks. The higher level `asap` function ensures that if an
// exception is thrown by a task, that the task queue will continue flushing as
// soon as possible, but if you use `rawAsap` directly, you are responsible to
// either ensure that no exceptions are thrown from your task, or to manually
// call `rawAsap.requestFlush` if an exception is thrown.
module.exports = rawAsap;
function rawAsap(task) {
    if (!queue.length) {
        requestFlush();
        flushing = true;
    }
    // Equivalent to push, but avoids a function call.
    queue[queue.length] = task;
}

var queue = [];
// Once a flush has been requested, no further calls to `requestFlush` are
// necessary until the next `flush` completes.
var flushing = false;
// `requestFlush` is an implementation-specific method that attempts to kick
// off a `flush` event as quickly as possible. `flush` will attempt to exhaust
// the event queue before yielding to the browser's own event loop.
var requestFlush;
// The position of the next task to execute in the task queue. This is
// preserved between calls to `flush` so that it can be resumed if
// a task throws an exception.
var index = 0;
// If a task schedules additional tasks recursively, the task queue can grow
// unbounded. To prevent memory exhaustion, the task queue will periodically
// truncate already-completed tasks.
var capacity = 1024;

// The flush function processes all tasks that have been scheduled with
// `rawAsap` unless and until one of those tasks throws an exception.
// If a task throws an exception, `flush` ensures that its state will remain
// consistent and will resume where it left off when called again.
// However, `flush` does not make any arrangements to be called again if an
// exception is thrown.
function flush() {
    while (index < queue.length) {
        var currentIndex = index;
        // Advance the index before calling the task. This ensures that we will
        // begin flushing on the next task the task throws an error.
        index = index + 1;
        queue[currentIndex].call();
        // Prevent leaking memory for long chains of recursive calls to `asap`.
        // If we call `asap` within tasks scheduled by `asap`, the queue will
        // grow, but to avoid an O(n) walk for every task we execute, we don't
        // shift tasks off the queue after they have been executed.
        // Instead, we periodically shift 1024 tasks off the queue.
        if (index > capacity) {
            // Manually shift all values starting at the index back to the
            // beginning of the queue.
            for (var scan = 0, newLength = queue.length - index; scan < newLength; scan++) {
                queue[scan] = queue[scan + index];
            }
            queue.length -= index;
            index = 0;
        }
    }
    queue.length = 0;
    index = 0;
    flushing = false;
}

// `requestFlush` is implemented using a strategy based on data collected from
// every available SauceLabs Selenium web driver worker at time of writing.
// https://docs.google.com/spreadsheets/d/1mG-5UYGup5qxGdEMWkhP6BWCz053NUb2E1QoUTU16uA/edit#gid=783724593

// Safari 6 and 6.1 for desktop, iPad, and iPhone are the only browsers that
// have WebKitMutationObserver but not un-prefixed MutationObserver.
// Must use `global` instead of `window` to work in both frames and web
// workers. `global` is a provision of Browserify, Mr, Mrs, or Mop.
var BrowserMutationObserver = global.MutationObserver || global.WebKitMutationObserver;

// MutationObservers are desirable because they have high priority and work
// reliably everywhere they are implemented.
// They are implemented in all modern browsers.
//
// - Android 4-4.3
// - Chrome 26-34
// - Firefox 14-29
// - Internet Explorer 11
// - iPad Safari 6-7.1
// - iPhone Safari 7-7.1
// - Safari 6-7
if (typeof BrowserMutationObserver === "function") {
    requestFlush = makeRequestCallFromMutationObserver(flush);

// MessageChannels are desirable because they give direct access to the HTML
// task queue, are implemented in Internet Explorer 10, Safari 5.0-1, and Opera
// 11-12, and in web workers in many engines.
// Although message channels yield to any queued rendering and IO tasks, they
// would be better than imposing the 4ms delay of timers.
// However, they do not work reliably in Internet Explorer or Safari.

// Internet Explorer 10 is the only browser that has setImmediate but does
// not have MutationObservers.
// Although setImmediate yields to the browser's renderer, it would be
// preferrable to falling back to setTimeout since it does not have
// the minimum 4ms penalty.
// Unfortunately there appears to be a bug in Internet Explorer 10 Mobile (and
// Desktop to a lesser extent) that renders both setImmediate and
// MessageChannel useless for the purposes of ASAP.
// https://github.com/kriskowal/q/issues/396

// Timers are implemented universally.
// We fall back to timers in workers in most engines, and in foreground
// contexts in the following browsers.
// However, note that even this simple case requires nuances to operate in a
// broad spectrum of browsers.
//
// - Firefox 3-13
// - Internet Explorer 6-9
// - iPad Safari 4.3
// - Lynx 2.8.7
} else {
    requestFlush = makeRequestCallFromTimer(flush);
}

// `requestFlush` requests that the high priority event queue be flushed as
// soon as possible.
// This is useful to prevent an error thrown in a task from stalling the event
// queue if the exception handled by Node.js’s
// `process.on("uncaughtException")` or by a domain.
rawAsap.requestFlush = requestFlush;

// To request a high priority event, we induce a mutation observer by toggling
// the text of a text node between "1" and "-1".
function makeRequestCallFromMutationObserver(callback) {
    var toggle = 1;
    var observer = new BrowserMutationObserver(callback);
    var node = document.createTextNode("");
    observer.observe(node, {characterData: true});
    return function requestCall() {
        toggle = -toggle;
        node.data = toggle;
    };
}

// The message channel technique was discovered by Malte Ubl and was the
// original foundation for this library.
// http://www.nonblocking.io/2011/06/windownexttick.html

// Safari 6.0.5 (at least) intermittently fails to create message ports on a
// page's first load. Thankfully, this version of Safari supports
// MutationObservers, so we don't need to fall back in that case.

// function makeRequestCallFromMessageChannel(callback) {
//     var channel = new MessageChannel();
//     channel.port1.onmessage = callback;
//     return function requestCall() {
//         channel.port2.postMessage(0);
//     };
// }

// For reasons explained above, we are also unable to use `setImmediate`
// under any circumstances.
// Even if we were, there is another bug in Internet Explorer 10.
// It is not sufficient to assign `setImmediate` to `requestFlush` because
// `setImmediate` must be called *by name* and therefore must be wrapped in a
// closure.
// Never forget.

// function makeRequestCallFromSetImmediate(callback) {
//     return function requestCall() {
//         setImmediate(callback);
//     };
// }

// Safari 6.0 has a problem where timers will get lost while the user is
// scrolling. This problem does not impact ASAP because Safari 6.0 supports
// mutation observers, so that implementation is used instead.
// However, if we ever elect to use timers in Safari, the prevalent work-around
// is to add a scroll event listener that calls for a flush.

// `setTimeout` does not call the passed callback if the delay is less than
// approximately 7 in web workers in Firefox 8 through 18, and sometimes not
// even then.

function makeRequestCallFromTimer(callback) {
    return function requestCall() {
        // We dispatch a timeout with a specified delay of 0 for engines that
        // can reliably accommodate that request. This will usually be snapped
        // to a 4 milisecond delay, but once we're flushing, there's no delay
        // between events.
        var timeoutHandle = setTimeout(handleTimer, 0);
        // However, since this timer gets frequently dropped in Firefox
        // workers, we enlist an interval handle that will try to fire
        // an event 20 times per second until it succeeds.
        var intervalHandle = setInterval(handleTimer, 50);

        function handleTimer() {
            // Whichever timer succeeds will cancel both timers and
            // execute the callback.
            clearTimeout(timeoutHandle);
            clearInterval(intervalHandle);
            callback();
        }
    };
}

// This is for `asap.js` only.
// Its name will be periodically randomized to break any code that depends on
// its existence.
rawAsap.makeRequestCallFromTimer = makeRequestCallFromTimer;

// ASAP was originally a nextTick shim included in Q. This was factored out
// into this ASAP package. It was later adapted to RSVP which made further
// amendments. These decisions, particularly to marginalize MessageChannel and
// to capture the MutationObserver implementation in a closure, were integrated
// back into ASAP proper.
// https://github.com/tildeio/rsvp.js/blob/cddf7232546a9cf858524b75cde6f9edf72620a7/lib/rsvp/asap.js

}).call(this,typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})
},{}],14:[function(require,module,exports){

},{}],15:[function(require,module,exports){
(function (Buffer){
var clone = (function() {
'use strict';

/**
 * Clones (copies) an Object using deep copying.
 *
 * This function supports circular references by default, but if you are certain
 * there are no circular references in your object, you can save some CPU time
 * by calling clone(obj, false).
 *
 * Caution: if `circular` is false and `parent` contains circular references,
 * your program may enter an infinite loop and crash.
 *
 * @param `parent` - the object to be cloned
 * @param `circular` - set to true if the object to be cloned may contain
 *    circular references. (optional - true by default)
 * @param `depth` - set to a number if the object is only to be cloned to
 *    a particular depth. (optional - defaults to Infinity)
 * @param `prototype` - sets the prototype to be used when cloning an object.
 *    (optional - defaults to parent prototype).
*/
function clone(parent, circular, depth, prototype) {
  var filter;
  if (typeof circular === 'object') {
    depth = circular.depth;
    prototype = circular.prototype;
    filter = circular.filter;
    circular = circular.circular
  }
  // maintain two arrays for circular references, where corresponding parents
  // and children have the same index
  var allParents = [];
  var allChildren = [];

  var useBuffer = typeof Buffer != 'undefined';

  if (typeof circular == 'undefined')
    circular = true;

  if (typeof depth == 'undefined')
    depth = Infinity;

  // recurse this function so we don't reset allParents and allChildren
  function _clone(parent, depth) {
    // cloning null always returns null
    if (parent === null)
      return null;

    if (depth == 0)
      return parent;

    var child;
    var proto;
    if (typeof parent != 'object') {
      return parent;
    }

    if (clone.__isArray(parent)) {
      child = [];
    } else if (clone.__isRegExp(parent)) {
      child = new RegExp(parent.source, __getRegExpFlags(parent));
      if (parent.lastIndex) child.lastIndex = parent.lastIndex;
    } else if (clone.__isDate(parent)) {
      child = new Date(parent.getTime());
    } else if (useBuffer && Buffer.isBuffer(parent)) {
      child = new Buffer(parent.length);
      parent.copy(child);
      return child;
    } else {
      if (typeof prototype == 'undefined') {
        proto = Object.getPrototypeOf(parent);
        child = Object.create(proto);
      }
      else {
        child = Object.create(prototype);
        proto = prototype;
      }
    }

    if (circular) {
      var index = allParents.indexOf(parent);

      if (index != -1) {
        return allChildren[index];
      }
      allParents.push(parent);
      allChildren.push(child);
    }

    for (var i in parent) {
      var attrs;
      if (proto) {
        attrs = Object.getOwnPropertyDescriptor(proto, i);
      }

      if (attrs && attrs.set == null) {
        continue;
      }
      child[i] = _clone(parent[i], depth - 1);
    }

    return child;
  }

  return _clone(parent, depth);
}

/**
 * Simple flat clone using prototype, accepts only objects, usefull for property
 * override on FLAT configuration object (no nested props).
 *
 * USE WITH CAUTION! This may not behave as you wish if you do not know how this
 * works.
 */
clone.clonePrototype = function clonePrototype(parent) {
  if (parent === null)
    return null;

  var c = function () {};
  c.prototype = parent;
  return new c();
};

// private utility functions

function __objToStr(o) {
  return Object.prototype.toString.call(o);
};
clone.__objToStr = __objToStr;

function __isDate(o) {
  return typeof o === 'object' && __objToStr(o) === '[object Date]';
};
clone.__isDate = __isDate;

function __isArray(o) {
  return typeof o === 'object' && __objToStr(o) === '[object Array]';
};
clone.__isArray = __isArray;

function __isRegExp(o) {
  return typeof o === 'object' && __objToStr(o) === '[object RegExp]';
};
clone.__isRegExp = __isRegExp;

function __getRegExpFlags(re) {
  var flags = '';
  if (re.global) flags += 'g';
  if (re.ignoreCase) flags += 'i';
  if (re.multiline) flags += 'm';
  return flags;
};
clone.__getRegExpFlags = __getRegExpFlags;

return clone;
})();

if (typeof module === 'object' && module.exports) {
  module.exports = clone;
}

}).call(this,require("buffer").Buffer)
},{"buffer":14}],16:[function(require,module,exports){
// Generated by CoffeeScript 1.7.1
(function() {
  var Parser,
    __slice = [].slice;

  Parser = (function() {
    function Parser(pf) {
      this.pf = pf;
    }

    Parser.prototype.parse = function(text) {
      var res;
      Parser.prototype._text = text;
      res = this.pf(0);
      if (res[0] === null) {
        throw Parser.error("Parsing failed", res[1]);
      }
      return res[0];
    };

    Parser.unit = function(v) {
      return new Parser(function(offset) {
        return [v, offset];
      });
    };

    Parser.prototype.bind = function(f) {
      return new Parser((function(_this) {
        return function(offset) {
          var res;
          res = _this.pf(offset);
          if (res[0] === null) {
            return [null, res[1]];
          } else {
            return (f(res[0])).pf(res[1]);
          }
        };
      })(this));
    };

    Parser.prototype.orElse = function(other) {
      return new Parser((function(_this) {
        return function(offset) {
          var res;
          res = _this.pf(offset);
          if (res[0] === null) {
            return other.pf(offset);
          } else {
            return res;
          }
        };
      })(this));
    };

    Parser.choice = function() {
      var p, q;
      p = arguments[0], q = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      if (q.length === 0) {
        return p;
      } else {
        return p.orElse(Parser.choice.apply(null, q));
      }
    };

    Parser.prototype.many = function(min) {
      if (min == null) {
        min = 0;
      }
      return new Parser((function(_this) {
        return function(offset) {
          var npt, pt, res, val, _ref;
          res = [];
          pt = offset;
          while (true) {
            _ref = _this.pf(pt), val = _ref[0], npt = _ref[1];
            if (val === null) {
              break;
            }
            res.push(val);
            pt = npt;
          }
          if (res.length < min) {
            return [null, npt];
          } else {
            return [res, pt];
          }
        };
      })(this));
    };

    Parser.prototype.concat = function(min) {
      return this.many(min).bind(function(arr) {
        return Parser.unit(arr.join(''));
      });
    };

    Parser.prototype.skipMany = function(min) {
      if (min == null) {
        min = 0;
      }
      return new Parser((function(_this) {
        return function(offset) {
          var cnt, npt, pt, val, _ref;
          cnt = 0;
          pt = offset;
          while (true) {
            _ref = _this.pf(pt), val = _ref[0], npt = _ref[1];
            if (val === null) {
              break;
            }
            cnt++;
            pt = npt;
          }
          if (cnt < min) {
            return [null, npt];
          } else {
            return [cnt, pt];
          }
        };
      })(this));
    };

    Parser.prototype.manyTill = function(end) {
      return new Parser((function(_this) {
        return function(offset) {
          var npt, pt, res, val, _ref, _ref1;
          res = [];
          pt = offset;
          while (true) {
            _ref = end.pf(pt), val = _ref[0], npt = _ref[1];
            if (val !== null) {
              return [res, npt];
            }
            _ref1 = _this.pf(pt), val = _ref1[0], pt = _ref1[1];
            if (val === null) {
              return [null, pt];
            }
            res.push(val);
          }
        };
      })(this));
    };

    Parser.prototype.repeat = function(count) {
      if (count == null) {
        count = 2;
      }
      if (count <= 0) {
        return Parser.unit([]);
      } else {
        return this.bind((function(_this) {
          return function(head) {
            return _this.repeat(count - 1).bind(function(tail) {
              tail.unshift(head);
              return Parser.unit(tail);
            });
          };
        })(this));
      }
    };

    Parser.prototype.between = function(lft, rt) {
      return lft.bind((function(_this) {
        return function() {
          return _this.bind(function(res) {
            return rt.bind(function() {
              return Parser.unit(res);
            });
          });
        };
      })(this));
    };

    Parser.prototype.option = function(dflt) {
      if (dflt == null) {
        dflt = '';
      }
      return this.orElse(Parser.unit(dflt));
    };

    Parser.prototype.sepBy = function(sep, min) {
      if (min == null) {
        min = 0;
      }
      if (min === 0) {
        return this.sepBy(sep, 1).orElse(Parser.unit([]));
      } else {
        return this.bind((function(_this) {
          return function(head) {
            return (sep.bind(function() {
              return _this;
            })).many(min - 1).bind(function(tail) {
              tail.unshift(head);
              return Parser.unit(tail);
            });
          };
        })(this));
      }
    };

    Parser.prototype.endBy = function(sep, min) {
      if (min == null) {
        min = 0;
      }
      return (this.bind(function(x) {
        return sep.bind(function() {
          return Parser.unit(x);
        });
      })).many(min);
    };

    Parser.prototype.sepEndBy = function(sep, min) {
      if (min == null) {
        min = 0;
      }
      return this.sepBy(sep, min).bind(function(res) {
        return sep.option().bind(function() {
          return Parser.unit(res);
        });
      });
    };

    Parser.prototype.notFollowedBy = function(p) {
      return this.bind(function(res) {
        return new Parser(function(offset) {
          var val;
          val = (p.pf(offset))[0] === null ? res : null;
          return [val, offset];
        });
      });
    };

    Parser.eof = new Parser(function(offset) {
      var res;
      res = offset >= this._text.length ? true : null;
      return [res, offset];
    });

    Parser.anyChar = new Parser(function(offset) {
      var next;
      next = this._text[offset++];
      if (next != null) {
        return [next, offset];
      } else {
        return [null, offset];
      }
    });

    Parser.sat = function(pred) {
      return Parser.anyChar.bind(function(x) {
        if (pred(x)) {
          return Parser.unit(x);
        } else {
          return new Parser(function(offset) {
            return [null, offset - 1];
          });
        }
      });
    };

    Parser.char = function(ch) {
      return Parser.sat(function(x) {
        return ch === x;
      });
    };

    Parser.oneOf = function(alts) {
      return Parser.sat(function(x) {
        return alts.indexOf(x) >= 0;
      });
    };

    Parser.noneOf = function(alts) {
      return Parser.sat(function(x) {
        return alts.indexOf(x) === -1;
      });
    };

    Parser.lower = Parser.sat(function(x) {
      return /^[a-z]$/.test(x);
    });

    Parser.upper = Parser.sat(function(x) {
      return /^[A-Z]$/.test(x);
    });

    Parser.alphanum = Parser.sat(function(x) {
      return /^\w$/.test(x);
    });

    Parser.space = Parser.sat(function(x) {
      return /^\s$/.test(x);
    });

    Parser.digit = Parser.oneOf('0123456789');

    Parser.octDigit = Parser.oneOf('01234567');

    Parser.hexDigit = Parser.oneOf('01234567abcdefABCDEF');

    Parser.nat0 = Parser.digit.concat(1).bind(function(ds) {
      return Parser.unit(Number(ds));
    });

    Parser.letter = Parser.lower.orElse(Parser.upper);

    Parser.skipSpace = Parser.space.skipMany();

    Parser.string = function(str) {
      return new Parser(function(offset) {
        if (str === this._text.substr(offset, str.length)) {
          return [str, offset + str.length];
        } else {
          return [null, offset];
        }
      });
    };

    Parser.offset = new Parser(function(offset) {
      return [offset, offset];
    });

    Parser.offset2coords = function(offset, tab) {
      var beg, expTab, lf, ln;
      if (tab == null) {
        tab = 8;
      }
      expTab = function(from, to) {
        var c, cnt, _i, _len, _ref;
        cnt = 0;
        _ref = Parser.prototype._text.slice(from, to);
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          c = _ref[_i];
          cnt += c === '\t' ? tab : 1;
        }
        return cnt;
      };
      ln = 1;
      beg = 0;
      while (true) {
        lf = Parser.prototype._text.indexOf('\n', beg);
        if (lf === -1 || lf >= offset) {
          break;
        }
        ln += 1;
        beg = lf + 1;
      }
      return [ln, expTab(beg, offset)];
    };

    Parser.coordinates = new Parser(function(offset) {
      return [Parser.offset2coords(offset), offset];
    });

    Parser.error = function(msg, offset) {
      var res;
      res = new Error(msg);
      res.name = 'ParsingError';
      res.offset = offset;
      res.coords = this.offset2coords(offset);
      return res;
    };

    return Parser;

  })();

  if (module.exports != null) {
    module.exports = Parser;
  } else {
    this.Parser = Parser;
  }

}).call(this);

},{}],17:[function(require,module,exports){
// Copyright Joyent, Inc. and other Node contributors.
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to permit
// persons to whom the Software is furnished to do so, subject to the
// following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
// NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
// DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
// USE OR OTHER DEALINGS IN THE SOFTWARE.

function EventEmitter() {
  this._events = this._events || {};
  this._maxListeners = this._maxListeners || undefined;
}
module.exports = EventEmitter;

// Backwards-compat with node 0.10.x
EventEmitter.EventEmitter = EventEmitter;

EventEmitter.prototype._events = undefined;
EventEmitter.prototype._maxListeners = undefined;

// By default EventEmitters will print a warning if more than 10 listeners are
// added to it. This is a useful default which helps finding memory leaks.
EventEmitter.defaultMaxListeners = 10;

// Obviously not all Emitters should be limited to 10. This function allows
// that to be increased. Set to zero for unlimited.
EventEmitter.prototype.setMaxListeners = function(n) {
  if (!isNumber(n) || n < 0 || isNaN(n))
    throw TypeError('n must be a positive number');
  this._maxListeners = n;
  return this;
};

EventEmitter.prototype.emit = function(type) {
  var er, handler, len, args, i, listeners;

  if (!this._events)
    this._events = {};

  // If there is no 'error' event listener then throw.
  if (type === 'error') {
    if (!this._events.error ||
        (isObject(this._events.error) && !this._events.error.length)) {
      er = arguments[1];
      if (er instanceof Error) {
        throw er; // Unhandled 'error' event
      }
      throw TypeError('Uncaught, unspecified "error" event.');
    }
  }

  handler = this._events[type];

  if (isUndefined(handler))
    return false;

  if (isFunction(handler)) {
    switch (arguments.length) {
      // fast cases
      case 1:
        handler.call(this);
        break;
      case 2:
        handler.call(this, arguments[1]);
        break;
      case 3:
        handler.call(this, arguments[1], arguments[2]);
        break;
      // slower
      default:
        args = Array.prototype.slice.call(arguments, 1);
        handler.apply(this, args);
    }
  } else if (isObject(handler)) {
    args = Array.prototype.slice.call(arguments, 1);
    listeners = handler.slice();
    len = listeners.length;
    for (i = 0; i < len; i++)
      listeners[i].apply(this, args);
  }

  return true;
};

EventEmitter.prototype.addListener = function(type, listener) {
  var m;

  if (!isFunction(listener))
    throw TypeError('listener must be a function');

  if (!this._events)
    this._events = {};

  // To avoid recursion in the case that type === "newListener"! Before
  // adding it to the listeners, first emit "newListener".
  if (this._events.newListener)
    this.emit('newListener', type,
              isFunction(listener.listener) ?
              listener.listener : listener);

  if (!this._events[type])
    // Optimize the case of one listener. Don't need the extra array object.
    this._events[type] = listener;
  else if (isObject(this._events[type]))
    // If we've already got an array, just append.
    this._events[type].push(listener);
  else
    // Adding the second element, need to change to array.
    this._events[type] = [this._events[type], listener];

  // Check for listener leak
  if (isObject(this._events[type]) && !this._events[type].warned) {
    if (!isUndefined(this._maxListeners)) {
      m = this._maxListeners;
    } else {
      m = EventEmitter.defaultMaxListeners;
    }

    if (m && m > 0 && this._events[type].length > m) {
      this._events[type].warned = true;
      console.error('(node) warning: possible EventEmitter memory ' +
                    'leak detected. %d listeners added. ' +
                    'Use emitter.setMaxListeners() to increase limit.',
                    this._events[type].length);
      if (typeof console.trace === 'function') {
        // not supported in IE 10
        console.trace();
      }
    }
  }

  return this;
};

EventEmitter.prototype.on = EventEmitter.prototype.addListener;

EventEmitter.prototype.once = function(type, listener) {
  if (!isFunction(listener))
    throw TypeError('listener must be a function');

  var fired = false;

  function g() {
    this.removeListener(type, g);

    if (!fired) {
      fired = true;
      listener.apply(this, arguments);
    }
  }

  g.listener = listener;
  this.on(type, g);

  return this;
};

// emits a 'removeListener' event iff the listener was removed
EventEmitter.prototype.removeListener = function(type, listener) {
  var list, position, length, i;

  if (!isFunction(listener))
    throw TypeError('listener must be a function');

  if (!this._events || !this._events[type])
    return this;

  list = this._events[type];
  length = list.length;
  position = -1;

  if (list === listener ||
      (isFunction(list.listener) && list.listener === listener)) {
    delete this._events[type];
    if (this._events.removeListener)
      this.emit('removeListener', type, listener);

  } else if (isObject(list)) {
    for (i = length; i-- > 0;) {
      if (list[i] === listener ||
          (list[i].listener && list[i].listener === listener)) {
        position = i;
        break;
      }
    }

    if (position < 0)
      return this;

    if (list.length === 1) {
      list.length = 0;
      delete this._events[type];
    } else {
      list.splice(position, 1);
    }

    if (this._events.removeListener)
      this.emit('removeListener', type, listener);
  }

  return this;
};

EventEmitter.prototype.removeAllListeners = function(type) {
  var key, listeners;

  if (!this._events)
    return this;

  // not listening for removeListener, no need to emit
  if (!this._events.removeListener) {
    if (arguments.length === 0)
      this._events = {};
    else if (this._events[type])
      delete this._events[type];
    return this;
  }

  // emit removeListener for all listeners on all events
  if (arguments.length === 0) {
    for (key in this._events) {
      if (key === 'removeListener') continue;
      this.removeAllListeners(key);
    }
    this.removeAllListeners('removeListener');
    this._events = {};
    return this;
  }

  listeners = this._events[type];

  if (isFunction(listeners)) {
    this.removeListener(type, listeners);
  } else if (listeners) {
    // LIFO order
    while (listeners.length)
      this.removeListener(type, listeners[listeners.length - 1]);
  }
  delete this._events[type];

  return this;
};

EventEmitter.prototype.listeners = function(type) {
  var ret;
  if (!this._events || !this._events[type])
    ret = [];
  else if (isFunction(this._events[type]))
    ret = [this._events[type]];
  else
    ret = this._events[type].slice();
  return ret;
};

EventEmitter.prototype.listenerCount = function(type) {
  if (this._events) {
    var evlistener = this._events[type];

    if (isFunction(evlistener))
      return 1;
    else if (evlistener)
      return evlistener.length;
  }
  return 0;
};

EventEmitter.listenerCount = function(emitter, type) {
  return emitter.listenerCount(type);
};

function isFunction(arg) {
  return typeof arg === 'function';
}

function isNumber(arg) {
  return typeof arg === 'number';
}

function isObject(arg) {
  return typeof arg === 'object' && arg !== null;
}

function isUndefined(arg) {
  return arg === void 0;
}

},{}],18:[function(require,module,exports){
'use strict';
var repeating = require('repeating');

module.exports = function (str, indent, count) {
	if (typeof str !== 'string' || typeof indent !== 'string') {
		throw new TypeError('`string` and `indent` should be strings');
	}

	if (count != null && typeof count !== 'number') {
		throw new TypeError('`count` should be a number');
	}

	if (count === 0) {
		return str;
	}

	indent = count > 1 ? repeating(indent, count) : indent;

	return str.replace(/^(?!\s*$)/mg, indent);
};

},{"repeating":31}],19:[function(require,module,exports){
'use strict';
var numberIsNan = require('number-is-nan');

module.exports = Number.isFinite || function (val) {
	return !(typeof val !== 'number' || numberIsNan(val) || val === Infinity || val === -Infinity);
};

},{"number-is-nan":20}],20:[function(require,module,exports){
'use strict';
module.exports = Number.isNaN || function (x) {
	return x !== x;
};

},{}],21:[function(require,module,exports){
(function (process){
// Copyright Joyent, Inc. and other Node contributors.
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to permit
// persons to whom the Software is furnished to do so, subject to the
// following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
// NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
// DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
// USE OR OTHER DEALINGS IN THE SOFTWARE.

// resolves . and .. elements in a path array with directory names there
// must be no slashes, empty elements, or device names (c:\) in the array
// (so also no leading and trailing slashes - it does not distinguish
// relative and absolute paths)
function normalizeArray(parts, allowAboveRoot) {
  // if the path tries to go above the root, `up` ends up > 0
  var up = 0;
  for (var i = parts.length - 1; i >= 0; i--) {
    var last = parts[i];
    if (last === '.') {
      parts.splice(i, 1);
    } else if (last === '..') {
      parts.splice(i, 1);
      up++;
    } else if (up) {
      parts.splice(i, 1);
      up--;
    }
  }

  // if the path is allowed to go above the root, restore leading ..s
  if (allowAboveRoot) {
    for (; up--; up) {
      parts.unshift('..');
    }
  }

  return parts;
}

// Split a filename into [root, dir, basename, ext], unix version
// 'root' is just a slash, or nothing.
var splitPathRe =
    /^(\/?|)([\s\S]*?)((?:\.{1,2}|[^\/]+?|)(\.[^.\/]*|))(?:[\/]*)$/;
var splitPath = function(filename) {
  return splitPathRe.exec(filename).slice(1);
};

// path.resolve([from ...], to)
// posix version
exports.resolve = function() {
  var resolvedPath = '',
      resolvedAbsolute = false;

  for (var i = arguments.length - 1; i >= -1 && !resolvedAbsolute; i--) {
    var path = (i >= 0) ? arguments[i] : process.cwd();

    // Skip empty and invalid entries
    if (typeof path !== 'string') {
      throw new TypeError('Arguments to path.resolve must be strings');
    } else if (!path) {
      continue;
    }

    resolvedPath = path + '/' + resolvedPath;
    resolvedAbsolute = path.charAt(0) === '/';
  }

  // At this point the path should be resolved to a full absolute path, but
  // handle relative paths to be safe (might happen when process.cwd() fails)

  // Normalize the path
  resolvedPath = normalizeArray(filter(resolvedPath.split('/'), function(p) {
    return !!p;
  }), !resolvedAbsolute).join('/');

  return ((resolvedAbsolute ? '/' : '') + resolvedPath) || '.';
};

// path.normalize(path)
// posix version
exports.normalize = function(path) {
  var isAbsolute = exports.isAbsolute(path),
      trailingSlash = substr(path, -1) === '/';

  // Normalize the path
  path = normalizeArray(filter(path.split('/'), function(p) {
    return !!p;
  }), !isAbsolute).join('/');

  if (!path && !isAbsolute) {
    path = '.';
  }
  if (path && trailingSlash) {
    path += '/';
  }

  return (isAbsolute ? '/' : '') + path;
};

// posix version
exports.isAbsolute = function(path) {
  return path.charAt(0) === '/';
};

// posix version
exports.join = function() {
  var paths = Array.prototype.slice.call(arguments, 0);
  return exports.normalize(filter(paths, function(p, index) {
    if (typeof p !== 'string') {
      throw new TypeError('Arguments to path.join must be strings');
    }
    return p;
  }).join('/'));
};


// path.relative(from, to)
// posix version
exports.relative = function(from, to) {
  from = exports.resolve(from).substr(1);
  to = exports.resolve(to).substr(1);

  function trim(arr) {
    var start = 0;
    for (; start < arr.length; start++) {
      if (arr[start] !== '') break;
    }

    var end = arr.length - 1;
    for (; end >= 0; end--) {
      if (arr[end] !== '') break;
    }

    if (start > end) return [];
    return arr.slice(start, end - start + 1);
  }

  var fromParts = trim(from.split('/'));
  var toParts = trim(to.split('/'));

  var length = Math.min(fromParts.length, toParts.length);
  var samePartsLength = length;
  for (var i = 0; i < length; i++) {
    if (fromParts[i] !== toParts[i]) {
      samePartsLength = i;
      break;
    }
  }

  var outputParts = [];
  for (var i = samePartsLength; i < fromParts.length; i++) {
    outputParts.push('..');
  }

  outputParts = outputParts.concat(toParts.slice(samePartsLength));

  return outputParts.join('/');
};

exports.sep = '/';
exports.delimiter = ':';

exports.dirname = function(path) {
  var result = splitPath(path),
      root = result[0],
      dir = result[1];

  if (!root && !dir) {
    // No dirname whatsoever
    return '.';
  }

  if (dir) {
    // It has a dirname, strip trailing slash
    dir = dir.substr(0, dir.length - 1);
  }

  return root + dir;
};


exports.basename = function(path, ext) {
  var f = splitPath(path)[2];
  // TODO: make this comparison case-insensitive on windows?
  if (ext && f.substr(-1 * ext.length) === ext) {
    f = f.substr(0, f.length - ext.length);
  }
  return f;
};


exports.extname = function(path) {
  return splitPath(path)[3];
};

function filter (xs, f) {
    if (xs.filter) return xs.filter(f);
    var res = [];
    for (var i = 0; i < xs.length; i++) {
        if (f(xs[i], i, xs)) res.push(xs[i]);
    }
    return res;
}

// String.prototype.substr - negative index don't work in IE8
var substr = 'ab'.substr(-1) === 'b'
    ? function (str, start, len) { return str.substr(start, len) }
    : function (str, start, len) {
        if (start < 0) start = str.length + start;
        return str.substr(start, len);
    }
;

}).call(this,require('_process'))
},{"_process":22}],22:[function(require,module,exports){
// shim for using process in browser

var process = module.exports = {};
var queue = [];
var draining = false;
var currentQueue;
var queueIndex = -1;

function cleanUpNextTick() {
    if (!draining || !currentQueue) {
        return;
    }
    draining = false;
    if (currentQueue.length) {
        queue = currentQueue.concat(queue);
    } else {
        queueIndex = -1;
    }
    if (queue.length) {
        drainQueue();
    }
}

function drainQueue() {
    if (draining) {
        return;
    }
    var timeout = setTimeout(cleanUpNextTick);
    draining = true;

    var len = queue.length;
    while(len) {
        currentQueue = queue;
        queue = [];
        while (++queueIndex < len) {
            if (currentQueue) {
                currentQueue[queueIndex].run();
            }
        }
        queueIndex = -1;
        len = queue.length;
    }
    currentQueue = null;
    draining = false;
    clearTimeout(timeout);
}

process.nextTick = function (fun) {
    var args = new Array(arguments.length - 1);
    if (arguments.length > 1) {
        for (var i = 1; i < arguments.length; i++) {
            args[i - 1] = arguments[i];
        }
    }
    queue.push(new Item(fun, args));
    if (queue.length === 1 && !draining) {
        setTimeout(drainQueue, 0);
    }
};

// v8 likes predictible objects
function Item(fun, array) {
    this.fun = fun;
    this.array = array;
}
Item.prototype.run = function () {
    this.fun.apply(null, this.array);
};
process.title = 'browser';
process.browser = true;
process.env = {};
process.argv = [];
process.version = ''; // empty string to avoid regexp issues
process.versions = {};

function noop() {}

process.on = noop;
process.addListener = noop;
process.once = noop;
process.off = noop;
process.removeListener = noop;
process.removeAllListeners = noop;
process.emit = noop;

process.binding = function (name) {
    throw new Error('process.binding is not supported');
};

process.cwd = function () { return '/' };
process.chdir = function (dir) {
    throw new Error('process.chdir is not supported');
};
process.umask = function() { return 0; };

},{}],23:[function(require,module,exports){
'use strict';

module.exports = require('./lib')

},{"./lib":28}],24:[function(require,module,exports){
'use strict';

var asap = require('asap/raw');

function noop() {}

// States:
//
// 0 - pending
// 1 - fulfilled with _value
// 2 - rejected with _value
// 3 - adopted the state of another promise, _value
//
// once the state is no longer pending (0) it is immutable

// All `_` prefixed properties will be reduced to `_{random number}`
// at build time to obfuscate them and discourage their use.
// We don't use symbols or Object.defineProperty to fully hide them
// because the performance isn't good enough.


// to avoid using try/catch inside critical functions, we
// extract them to here.
var LAST_ERROR = null;
var IS_ERROR = {};
function getThen(obj) {
  try {
    return obj.then;
  } catch (ex) {
    LAST_ERROR = ex;
    return IS_ERROR;
  }
}

function tryCallOne(fn, a) {
  try {
    return fn(a);
  } catch (ex) {
    LAST_ERROR = ex;
    return IS_ERROR;
  }
}
function tryCallTwo(fn, a, b) {
  try {
    fn(a, b);
  } catch (ex) {
    LAST_ERROR = ex;
    return IS_ERROR;
  }
}

module.exports = Promise;

function Promise(fn) {
  if (typeof this !== 'object') {
    throw new TypeError('Promises must be constructed via new');
  }
  if (typeof fn !== 'function') {
    throw new TypeError('not a function');
  }
  this._45 = 0;
  this._81 = 0;
  this._65 = null;
  this._54 = null;
  if (fn === noop) return;
  doResolve(fn, this);
}
Promise._10 = null;
Promise._97 = null;
Promise._61 = noop;

Promise.prototype.then = function(onFulfilled, onRejected) {
  if (this.constructor !== Promise) {
    return safeThen(this, onFulfilled, onRejected);
  }
  var res = new Promise(noop);
  handle(this, new Handler(onFulfilled, onRejected, res));
  return res;
};

function safeThen(self, onFulfilled, onRejected) {
  return new self.constructor(function (resolve, reject) {
    var res = new Promise(noop);
    res.then(resolve, reject);
    handle(self, new Handler(onFulfilled, onRejected, res));
  });
};
function handle(self, deferred) {
  while (self._81 === 3) {
    self = self._65;
  }
  if (Promise._10) {
    Promise._10(self);
  }
  if (self._81 === 0) {
    if (self._45 === 0) {
      self._45 = 1;
      self._54 = deferred;
      return;
    }
    if (self._45 === 1) {
      self._45 = 2;
      self._54 = [self._54, deferred];
      return;
    }
    self._54.push(deferred);
    return;
  }
  handleResolved(self, deferred);
}

function handleResolved(self, deferred) {
  asap(function() {
    var cb = self._81 === 1 ? deferred.onFulfilled : deferred.onRejected;
    if (cb === null) {
      if (self._81 === 1) {
        resolve(deferred.promise, self._65);
      } else {
        reject(deferred.promise, self._65);
      }
      return;
    }
    var ret = tryCallOne(cb, self._65);
    if (ret === IS_ERROR) {
      reject(deferred.promise, LAST_ERROR);
    } else {
      resolve(deferred.promise, ret);
    }
  });
}
function resolve(self, newValue) {
  // Promise Resolution Procedure: https://github.com/promises-aplus/promises-spec#the-promise-resolution-procedure
  if (newValue === self) {
    return reject(
      self,
      new TypeError('A promise cannot be resolved with itself.')
    );
  }
  if (
    newValue &&
    (typeof newValue === 'object' || typeof newValue === 'function')
  ) {
    var then = getThen(newValue);
    if (then === IS_ERROR) {
      return reject(self, LAST_ERROR);
    }
    if (
      then === self.then &&
      newValue instanceof Promise
    ) {
      self._81 = 3;
      self._65 = newValue;
      finale(self);
      return;
    } else if (typeof then === 'function') {
      doResolve(then.bind(newValue), self);
      return;
    }
  }
  self._81 = 1;
  self._65 = newValue;
  finale(self);
}

function reject(self, newValue) {
  self._81 = 2;
  self._65 = newValue;
  if (Promise._97) {
    Promise._97(self, newValue);
  }
  finale(self);
}
function finale(self) {
  if (self._45 === 1) {
    handle(self, self._54);
    self._54 = null;
  }
  if (self._45 === 2) {
    for (var i = 0; i < self._54.length; i++) {
      handle(self, self._54[i]);
    }
    self._54 = null;
  }
}

function Handler(onFulfilled, onRejected, promise){
  this.onFulfilled = typeof onFulfilled === 'function' ? onFulfilled : null;
  this.onRejected = typeof onRejected === 'function' ? onRejected : null;
  this.promise = promise;
}

/**
 * Take a potentially misbehaving resolver function and make sure
 * onFulfilled and onRejected are only called once.
 *
 * Makes no guarantees about asynchrony.
 */
function doResolve(fn, promise) {
  var done = false;
  var res = tryCallTwo(fn, function (value) {
    if (done) return;
    done = true;
    resolve(promise, value);
  }, function (reason) {
    if (done) return;
    done = true;
    reject(promise, reason);
  })
  if (!done && res === IS_ERROR) {
    done = true;
    reject(promise, LAST_ERROR);
  }
}

},{"asap/raw":13}],25:[function(require,module,exports){
'use strict';

var Promise = require('./core.js');

module.exports = Promise;
Promise.prototype.done = function (onFulfilled, onRejected) {
  var self = arguments.length ? this.then.apply(this, arguments) : this;
  self.then(null, function (err) {
    setTimeout(function () {
      throw err;
    }, 0);
  });
};

},{"./core.js":24}],26:[function(require,module,exports){
'use strict';

//This file contains the ES6 extensions to the core Promises/A+ API

var Promise = require('./core.js');

module.exports = Promise;

/* Static Functions */

var TRUE = valuePromise(true);
var FALSE = valuePromise(false);
var NULL = valuePromise(null);
var UNDEFINED = valuePromise(undefined);
var ZERO = valuePromise(0);
var EMPTYSTRING = valuePromise('');

function valuePromise(value) {
  var p = new Promise(Promise._61);
  p._81 = 1;
  p._65 = value;
  return p;
}
Promise.resolve = function (value) {
  if (value instanceof Promise) return value;

  if (value === null) return NULL;
  if (value === undefined) return UNDEFINED;
  if (value === true) return TRUE;
  if (value === false) return FALSE;
  if (value === 0) return ZERO;
  if (value === '') return EMPTYSTRING;

  if (typeof value === 'object' || typeof value === 'function') {
    try {
      var then = value.then;
      if (typeof then === 'function') {
        return new Promise(then.bind(value));
      }
    } catch (ex) {
      return new Promise(function (resolve, reject) {
        reject(ex);
      });
    }
  }
  return valuePromise(value);
};

Promise.all = function (arr) {
  var args = Array.prototype.slice.call(arr);

  return new Promise(function (resolve, reject) {
    if (args.length === 0) return resolve([]);
    var remaining = args.length;
    function res(i, val) {
      if (val && (typeof val === 'object' || typeof val === 'function')) {
        if (val instanceof Promise && val.then === Promise.prototype.then) {
          while (val._81 === 3) {
            val = val._65;
          }
          if (val._81 === 1) return res(i, val._65);
          if (val._81 === 2) reject(val._65);
          val.then(function (val) {
            res(i, val);
          }, reject);
          return;
        } else {
          var then = val.then;
          if (typeof then === 'function') {
            var p = new Promise(then.bind(val));
            p.then(function (val) {
              res(i, val);
            }, reject);
            return;
          }
        }
      }
      args[i] = val;
      if (--remaining === 0) {
        resolve(args);
      }
    }
    for (var i = 0; i < args.length; i++) {
      res(i, args[i]);
    }
  });
};

Promise.reject = function (value) {
  return new Promise(function (resolve, reject) {
    reject(value);
  });
};

Promise.race = function (values) {
  return new Promise(function (resolve, reject) {
    values.forEach(function(value){
      Promise.resolve(value).then(resolve, reject);
    });
  });
};

/* Prototype Methods */

Promise.prototype['catch'] = function (onRejected) {
  return this.then(null, onRejected);
};

},{"./core.js":24}],27:[function(require,module,exports){
'use strict';

var Promise = require('./core.js');

module.exports = Promise;
Promise.prototype['finally'] = function (f) {
  return this.then(function (value) {
    return Promise.resolve(f()).then(function () {
      return value;
    });
  }, function (err) {
    return Promise.resolve(f()).then(function () {
      throw err;
    });
  });
};

},{"./core.js":24}],28:[function(require,module,exports){
'use strict';

module.exports = require('./core.js');
require('./done.js');
require('./finally.js');
require('./es6-extensions.js');
require('./node-extensions.js');
require('./synchronous.js');

},{"./core.js":24,"./done.js":25,"./es6-extensions.js":26,"./finally.js":27,"./node-extensions.js":29,"./synchronous.js":30}],29:[function(require,module,exports){
'use strict';

// This file contains then/promise specific extensions that are only useful
// for node.js interop

var Promise = require('./core.js');
var asap = require('asap');

module.exports = Promise;

/* Static Functions */

Promise.denodeify = function (fn, argumentCount) {
  if (
    typeof argumentCount === 'number' && argumentCount !== Infinity
  ) {
    return denodeifyWithCount(fn, argumentCount);
  } else {
    return denodeifyWithoutCount(fn);
  }
}

var callbackFn = (
  'function (err, res) {' +
  'if (err) { rj(err); } else { rs(res); }' +
  '}'
);
function denodeifyWithCount(fn, argumentCount) {
  var args = [];
  for (var i = 0; i < argumentCount; i++) {
    args.push('a' + i);
  }
  var body = [
    'return function (' + args.join(',') + ') {',
    'var self = this;',
    'return new Promise(function (rs, rj) {',
    'var res = fn.call(',
    ['self'].concat(args).concat([callbackFn]).join(','),
    ');',
    'if (res &&',
    '(typeof res === "object" || typeof res === "function") &&',
    'typeof res.then === "function"',
    ') {rs(res);}',
    '});',
    '};'
  ].join('');
  return Function(['Promise', 'fn'], body)(Promise, fn);
}
function denodeifyWithoutCount(fn) {
  var fnLength = Math.max(fn.length - 1, 3);
  var args = [];
  for (var i = 0; i < fnLength; i++) {
    args.push('a' + i);
  }
  var body = [
    'return function (' + args.join(',') + ') {',
    'var self = this;',
    'var args;',
    'var argLength = arguments.length;',
    'if (arguments.length > ' + fnLength + ') {',
    'args = new Array(arguments.length + 1);',
    'for (var i = 0; i < arguments.length; i++) {',
    'args[i] = arguments[i];',
    '}',
    '}',
    'return new Promise(function (rs, rj) {',
    'var cb = ' + callbackFn + ';',
    'var res;',
    'switch (argLength) {',
    args.concat(['extra']).map(function (_, index) {
      return (
        'case ' + (index) + ':' +
        'res = fn.call(' + ['self'].concat(args.slice(0, index)).concat('cb').join(',') + ');' +
        'break;'
      );
    }).join(''),
    'default:',
    'args[argLength] = cb;',
    'res = fn.apply(self, args);',
    '}',
    
    'if (res &&',
    '(typeof res === "object" || typeof res === "function") &&',
    'typeof res.then === "function"',
    ') {rs(res);}',
    '});',
    '};'
  ].join('');

  return Function(
    ['Promise', 'fn'],
    body
  )(Promise, fn);
}

Promise.nodeify = function (fn) {
  return function () {
    var args = Array.prototype.slice.call(arguments);
    var callback =
      typeof args[args.length - 1] === 'function' ? args.pop() : null;
    var ctx = this;
    try {
      return fn.apply(this, arguments).nodeify(callback, ctx);
    } catch (ex) {
      if (callback === null || typeof callback == 'undefined') {
        return new Promise(function (resolve, reject) {
          reject(ex);
        });
      } else {
        asap(function () {
          callback.call(ctx, ex);
        })
      }
    }
  }
}

Promise.prototype.nodeify = function (callback, ctx) {
  if (typeof callback != 'function') return this;

  this.then(function (value) {
    asap(function () {
      callback.call(ctx, null, value);
    });
  }, function (err) {
    asap(function () {
      callback.call(ctx, err);
    });
  });
}

},{"./core.js":24,"asap":12}],30:[function(require,module,exports){
'use strict';

var Promise = require('./core.js');

module.exports = Promise;
Promise.enableSynchronous = function () {
  Promise.prototype.isPending = function() {
    return this.getState() == 0;
  };

  Promise.prototype.isFulfilled = function() {
    return this.getState() == 1;
  };

  Promise.prototype.isRejected = function() {
    return this.getState() == 2;
  };

  Promise.prototype.getValue = function () {
    if (this._81 === 3) {
      return this._65.getValue();
    }

    if (!this.isFulfilled()) {
      throw new Error('Cannot get a value of an unfulfilled promise.');
    }

    return this._65;
  };

  Promise.prototype.getReason = function () {
    if (this._81 === 3) {
      return this._65.getReason();
    }

    if (!this.isRejected()) {
      throw new Error('Cannot get a rejection reason of a non-rejected promise.');
    }

    return this._65;
  };

  Promise.prototype.getState = function () {
    if (this._81 === 3) {
      return this._65.getState();
    }
    if (this._81 === -1 || this._81 === -2) {
      return 0;
    }

    return this._81;
  };
};

Promise.disableSynchronous = function() {
  Promise.prototype.isPending = undefined;
  Promise.prototype.isFulfilled = undefined;
  Promise.prototype.isRejected = undefined;
  Promise.prototype.getValue = undefined;
  Promise.prototype.getReason = undefined;
  Promise.prototype.getState = undefined;
};

},{"./core.js":24}],31:[function(require,module,exports){
'use strict';
var isFinite = require('is-finite');

module.exports = function (str, n) {
	if (typeof str !== 'string') {
		throw new TypeError('Expected `input` to be a string');
	}

	if (n < 0 || !isFinite(n)) {
		throw new TypeError('Expected `count` to be a positive finite number');
	}

	var ret = '';

	do {
		if (n & 1) {
			ret += str;
		}

		str += str;
	} while ((n >>= 1));

	return ret;
};

},{"is-finite":19}],32:[function(require,module,exports){
// Generated by CoffeeScript 1.7.1
(function() {
  var P, YangStatement, argument, blockComment, comment, dqChar, dqLit, dqString, escape, identifier, keyword, lineComment, optSep, parse, qArg, semiOrBlock, sep, sqLit, statement, stmtBlock, uArg;

  P = require('comparse');

  YangStatement = (function() {
    function YangStatement(prf, kw, arg, substmts) {
      this.prf = prf;
      this.kw = kw;
      this.arg = arg;
      this.substmts = substmts;
    }

    return YangStatement;

  })();

  lineComment = (P.string('//')).bind(function() {
    return P.anyChar.manyTill(P.char('\n')).bind(function(cs) {
      return P.unit(cs.join(''));
    });
  });

  blockComment = (P.string('/*')).bind(function() {
    return P.anyChar.manyTill(P.string('*/')).bind(function(cs) {
      return P.unit(cs.join(''));
    });
  });

  comment = lineComment.orElse(blockComment);

  sep = (P.space.orElse(comment)).skipMany(1);

  optSep = (P.space.orElse(comment)).skipMany();

  identifier = (P.letter.orElse(P.char('_'))).bind(function(fst) {
    return (P.alphanum.orElse(P.oneOf('.-'))).many().bind(function(tail) {
      var res;
      res = fst + tail.join('');
      return P.unit(res.slice(0, 3).toLowerCase() === 'xml' ? null : res);
    });
  });

  keyword = (identifier.bind(function(prf) {
    return P.char(':').bind(function() {
      return P.unit(prf);
    });
  })).option().bind(function(pon) {
    return identifier.bind(function(kw) {
      return P.unit([pon, kw]);
    });
  });

  uArg = (P.noneOf(" '\"\n\t\r;{}/").orElse(P.char('/').notFollowedBy(P.oneOf('/*')))).concat(1);

  sqLit = P.sat(function(c) {
    return c !== "'";
  }).concat().between(P.char("'"), P.char("'"));

  escape = P.char('\\').bind(function() {
    var esc;
    esc = {
      't': '\t',
      'n': '\n',
      '"': '"',
      '\\': '\\'
    };
    return P.oneOf('tn"\\').bind(function(c) {
      return P.unit(esc[c]);
    });
  });

  dqChar = P.noneOf('"\\').orElse(escape);

  dqLit = P.char('"').bind(function() {
    return P.coordinates.bind(function(col) {
      return dqString(col[1]);
    });
  });

  dqString = function(lim) {
    var trimLead;
    trimLead = function(str) {
      var c, i, left, sptab;
      left = lim;
      sptab = '        ';
      i = 0;
      while (left > 0) {
        c = str[i++];
        if (c === ' ') {
          left -= 1;
        } else if (c === '\t') {
          if (left < 8) {
            return sptab.slice(0, 8 - left) + str.slice(i);
          }
          left -= 8;
        } else {
          return str.slice(i - 1);
        }
      }
      return str.slice(i);
    };
    return dqChar.manyTill(P.char('"')).bind(function(cs) {
      var lines, ln, mo, res, tlines, _i, _j, _len, _len1, _ref, _ref1;
      lines = cs.join('').split('\n');
      tlines = [lines[0]];
      _ref = lines.slice(1);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        ln = _ref[_i];
        tlines.push(trimLead(ln));
      }
      res = [];
      _ref1 = tlines.slice(0, -1);
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        ln = _ref1[_j];
        mo = ln.match(/(.*\S)?\s*/);
        res.push(mo[1]);
      }
      res.push(tlines.pop());
      return P.unit(res.join('\n'));
    });
  };

  qArg = dqLit.orElse(sqLit).bind(function(lft) {
    return (P.char('+').between(optSep, optSep).bind(function() {
      return qArg;
    })).option().bind(function(rt) {
      return P.unit(lft + rt);
    });
  });

  argument = uArg.orElse(qArg);

  statement = keyword.bind(function(kw) {
    return (sep.bind(function() {
      return argument;
    })).option().bind(function(arg) {
      return optSep.bind(function() {
        return semiOrBlock.bind(function(sst) {
          return P.unit(new YangStatement(kw[0], kw[1], arg, sst));
        });
      });
    });
  });

  stmtBlock = P.char('{').bind(function() {
    return (optSep.bind(function() {
      return statement;
    })).manyTill(optSep.bind(function() {
      return P.char('}');
    }));
  });

  semiOrBlock = (P.char(';').bind(function() {
    return P.unit([]);
  })).orElse(stmtBlock);

  parse = function(text, top) {
    var yst;
    if (top == null) {
      top = null;
    }
    yst = statement.between(optSep, optSep).parse(text);
    if ((top != null) && yst.kw !== top) {
      throw P.error("Wrong top-level statement", 0);
    }
    return yst;
  };

  module.exports = {
    parse: parse
  };

}).call(this);

},{"comparse":16}]},{},[5]);
