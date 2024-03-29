use Modern::Perl;
use Test::More;
use Test::Fatal;
use Simplist::Lexer qw(lex);
use Simplist::Parser qw(parse);
use Simplist::Eval qw(evaluate);
use Data::Dump qw(pp);

sub check {
  my $code = shift;
  my @tokens = lex($code);
  my $parsetree = parse(\@tokens);
  evaluate($parsetree)
}

sub run {
  check(shift)->{value};
}

like(exception { run(',1'); }, qr/unquote outside of a quasiquote/,
  "Cannot bare unquote");

like(exception { run(',@1'); }, qr/unquote-splicing outside of a quasiquote/,
  "Cannot bare unquote-splicing");

is_deeply run('`,1'), {type => 'num', value => 1},
  "quote-unquote";

is_deeply run('(let a 1 `,a)'), {type => 'num', value => 1},
  "unquote a variable";

is_deeply run('(import std (list)) (let a 1 `(list ,a))'), {
  type => 'list', exprs => [
    { type => 'id', value => 'list' },
    { type => 'num', value => 1 }
  ]
}, "unquote a variable in a list";

is_deeply run('(import std (list)) (eval (let a 1 `(list ,a)))'), {
  type => 'list', exprs => [
    { type => 'num', value => 1 }
  ]
}, "eval unquote";

is_deeply run('(import std (list)) (let trilist (macro (x) `(list ,x ,x ,x)) (trilist 1))'), {
  type => 'list', exprs => [
    { type => 'num', value => 1 },
    { type => 'num', value => 1 },
    { type => 'num', value => 1 },
  ]
}, "quasiquote in macro";

is_deeply run('
(let do
  (macro (body)
    `((lambda () ,@body)))
  (do (1 2 3 2 1)))'), {
  type => 'num', value => 1,
}, "unquote-splicing";


{
  use Capture::Tiny ':all';
  my $stdout = capture_stdout(sub {
    is_deeply run('
(import std (say +))
(let mylet
  (macro (name value body)
    `(let ,name ,value ((lambda () ,@body))))
  (mylet a 1
    ((say (+ a -1))
     (say a)
     (say (+ a 1))
     a)))
'), { type => 'num', value => 1, },
    "unquote, unquote-splicing";
  });
  is $stdout, "0\n1\n2\n", "elements were printed";
}

{
  use Capture::Tiny ':all';
  my $stdout = capture_stdout(sub {
    is_deeply run('
(import std (say))
(def twice
  (macro (x)
    `((lambda ()
      ,x
      ,x))))
(twice (say 1))
1
'), { type => 'num', value => 1 },
      'define twice macro';
  });
  is $stdout, "1\n1\n", "printed twice";
}

# TODO
#
#    (let a 1 (def x a))
#    x

is_deeply run('
(import std (say))
(def define-alias
  (macro (as aliased)
    `(def ,as
      (macro (name)
        `(def ,name ,\',aliased)))))
(def x 1)
(define-alias defx x)
(defx a)
a
'), { type => 'num', value => 1 },
  'nested quote-unquote';

is_deeply run('
(import std (say))
(def define-alias
  (macro (as x)
    `(def ,as
      (macro (name)
        `(def ,name ,\',x)))))
(define-alias defx 1)
(defx a)
a
'), { type => 'num', value => 1 },
  'nested quote-unquote';

is_deeply run('
(import std (say))
(def define-alias
  (macro (as x)
    `(def ,as
      (macro (name)
        `(def ,name ,\',x)))))
(def foo 1)
(define-alias defx foo)
(defx a)
a
'), { type => 'num', value => 1 },
  'nested quote-unquote and an id';

  #is_deeply run('
  #(import std (+))
  #(def define-op
  #  (macro (name xs)
  #    `(def ,name
  #      (macro (op)
  #        `(,op ,\',@xs)))))
  #(define-op of123 (1 2 3))
  #(of123 +)
  #'), { type => 'num', value => 6 },
  #  'nested quote-splicing_unquote';

# XXX error location
like(exception { run('`,@1'); }, qr/unquote-splicing outside of a list quasiquote/,
  "Cannot bare unquote-splicing");

done_testing;
