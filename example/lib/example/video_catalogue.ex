defmodule Example.VideoCatalogue do
  @moduledoc """
  In-memory catalogue of internal videos — "brown-bag" talks, all-hands
  recordings, onboarding clips.

  A real app would keep these in a database or a media service and stream from a
  CDN. Here it's a static seed; the `src` URLs point at Google's public
  sample-video bucket so the deployed demo actually plays, and `poster` uses the
  matching still images.
  """

  @type video :: %{
          id: String.t(),
          title: String.t(),
          presenter: String.t(),
          category: String.t(),
          duration: String.t(),
          description: String.t(),
          poster: String.t(),
          src: String.t()
        }

  @bucket "https://storage.googleapis.com/gtv-videos-bucket/sample"

  @videos [
    %{
      id: "all-hands-q3",
      title: "All-Hands: Q3 Vision",
      presenter: "Grace Hopper",
      category: "Company",
      duration: "9:56",
      description: "Where we're headed this quarter and why it matters.",
      file: "BigBuckBunny.mp4",
      image: "BigBuckBunny.jpg"
    },
    %{
      id: "islands-architecture",
      title: "Engineering Deep-Dive: Islands Architecture",
      presenter: "Ada Lovelace",
      category: "Engineering",
      duration: "10:53",
      description: "How autonomous Svelte islands mount into Phoenix pages.",
      file: "ElephantsDream.mp4",
      image: "ElephantsDream.jpg"
    },
    %{
      id: "token-handling",
      title: "Security Brown-Bag: Token Handling",
      presenter: "Alan Turing",
      category: "Security",
      duration: "0:15",
      description: "Short-lived, least-privilege tokens for calling other services.",
      file: "ForBiggerBlazes.mp4",
      image: "ForBiggerBlazes.jpg"
    },
    %{
      id: "workspace-ui",
      title: "Design Review: Workspace UI",
      presenter: "Katherine Johnson",
      category: "Design",
      duration: "0:15",
      description: "Walkthrough of the new workspace shell and navigation.",
      file: "ForBiggerEscapes.mp4",
      image: "ForBiggerEscapes.jpg"
    },
    %{
      id: "zero-downtime-deploys",
      title: "Infra: Zero-Downtime Deploys",
      presenter: "Linus Torvalds",
      category: "Infrastructure",
      duration: "0:15",
      description: "Rolling releases without dropping a single request.",
      file: "ForBiggerFun.mp4",
      image: "ForBiggerFun.jpg"
    },
    %{
      id: "first-week",
      title: "Onboarding: Your First Week",
      presenter: "Grace Hopper",
      category: "People",
      duration: "0:15",
      description: "Everything a new hire needs in the first five days.",
      file: "ForBiggerJoyrides.mp4",
      image: "ForBiggerJoyrides.jpg"
    },
    %{
      id: "incident-review",
      title: "Incident Review: The Great Outage",
      presenter: "Alan Turing",
      category: "Engineering",
      duration: "14:48",
      description: "A blameless retro on last month's incident.",
      file: "Sintel.mp4",
      image: "Sintel.jpg"
    },
    %{
      id: "product-demo",
      title: "Product Demo: Calendar & Chat",
      presenter: "Ada Lovelace",
      category: "Product",
      duration: "12:14",
      description: "The islands that make up the KeenSpace workspace.",
      file: "TearsOfSteel.mp4",
      image: "TearsOfSteel.jpg"
    }
  ]

  @doc "Every video, shaped for the client (absolute `poster` + `src` URLs)."
  @spec list() :: [video()]
  def list, do: Enum.map(@videos, &to_client/1)

  @doc "A single video by id, or nil."
  @spec get(String.t()) :: video() | nil
  def get(id) do
    case Enum.find(@videos, &(&1.id == id)) do
      nil -> nil
      video -> to_client(video)
    end
  end

  @doc "The distinct categories present in the catalogue, sorted."
  @spec categories() :: [String.t()]
  def categories do
    @videos |> Enum.map(& &1.category) |> Enum.uniq() |> Enum.sort()
  end

  defp to_client(video) do
    video
    |> Map.drop([:file, :image])
    |> Map.put(:src, "#{@bucket}/#{video.file}")
    |> Map.put(:poster, "#{@bucket}/images/#{video.image}")
  end
end
