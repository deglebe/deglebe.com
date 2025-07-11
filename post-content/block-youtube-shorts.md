# blocking the shorts in youtube

*10/07/2025*

humanity's recent obsession with scrolling can be fairly well explained by the
skinner box phenomenon[^1]. this is especially prevalent in recent years with
the unprecedented rise of short-form content. platforms such as tik-tok, reels,
etc. capitalize off of the amount of your time you are (un)willing to spend
scrolling through posts with the hope of illiciting a chuckle or smile or some
short-lived positive feeling. however, one may find that, with effective
introspection, these feelings tend to be neutral at best. as time is the most
valuable thing one can give away, wasting it on neutral emotions and making
money for already rich-beyond-imagination corporations seems like a shame.
unfortunately, the wealth of information, legitimate entertainment, and
good journalism present on youtube has become cluttered by google's own attempt
at capitalizing on short-form content. it's been a few years since it was added
to the platform, and more than once i've found myself sucked into it's sticky
arms. no longer. i'm not here to argue why shorts are bad, but present my
solution to the problem.

## existing solutions

there are a few solutions to this scourge:

- quitting youtube entirely
- trying to ignore it
- using invidious or another frontend
- [rss2email -> yt-dlp -> mpv](https://drewdevault.com/2016/11/16/Getting-on-without-Google.html)
- various extensions for firefox

unfortunately, quitting youtube is simply impractical for most (including
myself) due to the value detracted from it. trying to ignore it has been, on
occasion, unsuccessful. invidious public instances are somewhat finnicky and i
do not have the resources to dedicate to running an instance for myself. using
rss2email requires too much effort. lastly, i'm attempting to minimize the
number of extensions i am using so as to decrease fingerprinting.

## my solution

the past year or so, i've been working on streamlining my web experience by
writing tampermonkey scripts to get rid of various annoyances that pop up as i
spend time online. the past few days now have been spent cleaning up and
publishing these scripts in a repository. one of these scripts blocks all
references to shorts i could find via css injection, and then checks for any
other instances of shorts appearing and forces them not to load. super simple,
but it works, is 62 loc (including the tampermonkey header), and doesn't leave
gaps in the page.

## the source

here's the source, copyable so you can add it if you like:

```js
// ==UserScript==
// @name	hide youtube shorts
// @namespace	https://deglebe.com
// @version	1.0.0
// @description	nuke the shorts tab, section, and player from appearing in youtube
// @author	thomas "deglebe" bruce
// @match	https://www.youtube.com/*
// @run-at	document-start
// @grant	none
// ==/UserScript==

(() => {
  /* pure css fallback, works for most elements since css selectors are
   * reevaluated whenever the dom mutates */
  const css = `
    /* shorts shelf on home/subs pages */
    ytd-rich-shelf-renderer[is-shorts],
    /* shorts shelf in search results */
    ytd-reel-shelf-renderer,
    /* “shorts” side-bar nav button */
    a[title="Shorts"],
    #endpoint[title="Shorts"],
    /* shorts tab on channel pages */
    yt-tab-shape[tab-title="Shorts"],
    /* shorts chip on search-result filter bar */
    yt-chip-cloud-chip-renderer[chip-id*="shorts"]
  { display:none !important; }`;

  const s = document.createElement("style");
  s.id = "tm-hide-shorts";
  s.textContent = css;
  document.documentElement.appendChild(s);

  /* extra guard, removes shorts shelf that isn't in the css defaults */
  const SELECTORS = [
    "ytd-rich-shelf-renderer[is-shorts]",
    "ytd-reel-shelf-renderer",
  ];

  const zapShorts = (root) => {
    SELECTORS.forEach((sel) =>
      root.querySelectorAll(sel).forEach((el) => el.remove()),
    );
    /* detect shelves labelled “shorts” without the is-shorts attr */
    root.querySelectorAll("ytd-rich-shelf-renderer").forEach((shelf) => {
      const label = shelf.querySelector("#title span")?.textContent?.trim();
      if (label === "Shorts") shelf.remove();
    });
  };

  const mo = new MutationObserver((muts) =>
    muts.forEach((m) => m.addedNodes.forEach((n) => zapShorts(n))),
  );

  mo.observe(document.documentElement, {
    childList: true,
    subtree: true,
  });

  /* initial sweep for elements already present */
  zapShorts(document);
})();
```

## going forward and more scripts

there seems to be a new functionality in youtube, "playables." i don't really
spend much time on the homepage so i haven't given them much thought, but they
do appear to be another example of attention capitalization and enshittification
on the platform, so i may at some point write another script to remove that as
well.

the rest of the scripts i've written can be found at
[https://github.com/deglebe/tmscripts](https://github.com/deglebe/tmscripts)

have a good day!

[^1]: animals tend to continue reward-seeking behaviour due to the chance of reward, not necessarily the reward itself.
