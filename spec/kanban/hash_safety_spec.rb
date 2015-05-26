require_relative '../spec_helper'

using HashSafety

describe "HashSafety" do
  before do
    @symbol_hash = { foo: 1, bar: 2, baz: 3 }
    @string_hash = { 'foo' => 1, 'bar' => 2, 'baz' => 3 }
  end

  it 'should detect symbols in hash keys' do
    expect(@symbol_hash.keys_contain_symbols?).to be true
  end

  it 'should provide an alternate hash with string keys' do
    safe = @symbol_hash.with_string_keys
    expect(safe).to eq @string_hash
    expect(safe.keys_contain_symbols?).to be false
  end
end
