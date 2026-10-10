defmodule AgentProofWeb.Pagination do
  use AgentProofWeb, :html

  @doc """
  Page links, hidden when there is only one page. `page_path` turns a page number into a
  path.
  """
  attr :meta, Pagex.Meta, required: true
  attr :page_path, :any, required: true

  def pagination(assigns) do
    ~H"""
    <nav
      :if={@meta.total_pages > 1}
      id="pagination"
      aria-label="Pagination"
      class="flex flex-wrap items-center justify-center gap-2 py-6"
    >
      <.link
        :if={@meta.has_prev}
        id="page-prev"
        patch={@page_path.(@meta.page - 1)}
        class="btn btn-sm btn-outline"
      >
        « Prev
      </.link>

      <%!-- //1 keeps the range ascending; a plain 1..0 would count down. --%>
      <.link
        :for={page <- 1..@meta.total_pages//1}
        id={"page-#{page}"}
        patch={@page_path.(page)}
        aria-current={page == @meta.page && "page"}
        class={["btn btn-sm", if(page == @meta.page, do: "btn-primary", else: "btn-outline")]}
      >
        {page}
      </.link>

      <.link
        :if={@meta.has_next}
        id="page-next"
        patch={@page_path.(@meta.page + 1)}
        class="btn btn-sm btn-outline"
      >
        Next »
      </.link>
    </nav>
    """
  end
end
