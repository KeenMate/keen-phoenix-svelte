<script>
  import { onMount } from "svelte";
  import Plyr from "plyr";
  // `?inline` gives Plyr's CSS as a string so we can inject it ourselves —
  // islands ship no separate stylesheet, so a bare `import "plyr/dist/plyr.css"`
  // (which Vite would extract to a file we never load) wouldn't apply.
  import plyrCss from "plyr/dist/plyr.css?inline";

  let { video } = $props();

  let el = $state();
  let player;

  // Inject Plyr's stylesheet once per page.
  if (typeof document !== "undefined" && !document.getElementById("plyr-css")) {
    const style = document.createElement("style");
    style.id = "plyr-css";
    style.textContent = plyrCss;
    document.head.appendChild(style);
  }

  onMount(() => {
    player = new Plyr(el, { autoplay: true });
    return () => player?.destroy();
  });
</script>

<video bind:this={el} playsinline controls poster={video.poster}>
  <source src={video.src} type="video/mp4" />
  <track kind="captions" />
</video>
