log = console.log.bind console

class A
	constructor:->
	one:-> log 'A:one ' + @val

a = new A
a.val = 'hello'

class B extends A
	one:-> log 'B:one'; super
	two:-> log 'B:two'

a.__proto__ = B.prototype
B.call a

a.one()
a.two()

