module HashSafety
  refine Hash do
    def keys_contain_symbols?
      keys.count { |key| key.is_a? Symbol } > 0
    end

    def with_string_keys
      each_with_object({}) do |(key, value), hash|
        hash[key.to_s] = value
        hash
      end
    end
  end
end
