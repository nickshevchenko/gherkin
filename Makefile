GOOD_FEATURE_FILES = $(shell find ../testdata/good -name "*.feature")
BAD_FEATURE_FILES  = $(shell find ../testdata/bad -name "*.feature")

TOKENS   = $(patsubst ../testdata/%.feature,acceptance/testdata/%.feature.tokens,$(GOOD_FEATURE_FILES))
ASTS     = $(patsubst ../testdata/%.feature,acceptance/testdata/%.feature.ast.json,$(GOOD_FEATURE_FILES))

RUBY_FILES = $(shell find . -name "*.rb")

all: .compared
.PHONY: all

.compared: .built $(TOKENS) $(ASTS)
	touch $@

.built: lib/gherkin/parser.rb lib/gherkin/dialects.json $(RUBY_FILES)
	bundle exec rspec
	touch $@

acceptance/testdata/%.feature.tokens: ../testdata/%.feature ../testdata/%.feature.tokens .built
	mkdir -p `dirname $@`
	bundle exec ruby bin/gherkin-generate-tokens $< > $@ || (rm $@ && false)
	diff --unified --ignore-all-space $<.tokens $@ || (rm $@ && false)

acceptance/testdata/%.feature.ast.json: ../testdata/%.feature ../testdata/%.feature.ast.json .built
	mkdir -p `dirname $@`
	bundle exec ruby bin/gherkin-generate-ast $< | jq --sort-keys "." > $@ || (rm $@ && false)
	diff --unified --ignore-all-space $<.ast.json $@ || (rm $@ && false)

lib/gherkin/dialects.json: ../dialects.json
	cp $^ $@

clean:
	rm -rf .compared .built acceptance lib/gherkin/parser.rb lib/gherking/dialects.json
.PHONY: clean

lib/gherkin/parser.rb: ../gherkin.berp gherkin-ruby.razor ../bin/berp.exe
	mono ../bin/berp.exe -g ../gherkin.berp -t gherkin-ruby.razor -o $@
	# Remove BOM
	tail -c +4 $@ > $@.nobom
	mv $@.nobom $@
