defmodule Example.Catalog do
  @moduledoc """
  A deterministic, in-memory fake product catalog (500 items) backing the QR
  stress-test demo (`/stress`). No database — the list is built once at compile
  time from the item index, so titles/prices are stable across reloads and every
  process sees the same catalog.
  """

  @adjectives ~w(Compact Rugged Wireless Ergonomic Premium Portable Modular
                 Silent Heavy-Duty Ultra Slim Smart Classic Vintage Pro Mini)

  @materials ~w(Aluminium Carbon Bamboo Steel Titanium Walnut Recycled Ceramic)

  @nouns ~w(Keyboard Mouse Monitor Desk Lamp Chair Headset Speaker Webcam
            Router Charger Backpack Bottle Notebook Stand Hub Cable Adapter
            Trackpad Microphone)

  @adj_count length(@adjectives)
  @mat_count length(@materials)
  @noun_count length(@nouns)

  @products (for i <- 1..500 do
               adj = Enum.at(@adjectives, rem(i, @adj_count))
               mat = Enum.at(@materials, rem(div(i, @adj_count), @mat_count))
               noun = Enum.at(@nouns, rem(div(i, @adj_count * @mat_count), @noun_count))

               %{
                 code: "SKU-" <> String.pad_leading(Integer.to_string(i), 4, "0"),
                 title: "#{adj} #{mat} #{noun}",
                 # 1.99 .. ~99.99, stable per item
                 unit_price: Float.round((199 + rem(i * 173, 9800)) / 100, 2)
               }
             end)

  @doc "All 500 products."
  def all, do: @products

  @doc "Total catalog size."
  def count, do: length(@products)

  @doc """
  Case-insensitive substring match over code + title. A blank query returns the
  whole catalog (the maximum-stress case: every row renders a QR island).
  """
  def search(query) when is_binary(query) do
    case String.trim(query) do
      "" ->
        @products

      q ->
        needle = String.downcase(q)

        Enum.filter(@products, fn p ->
          String.contains?(String.downcase(p.code), needle) or
            String.contains?(String.downcase(p.title), needle)
        end)
    end
  end

  def search(_), do: @products
end
