# limelight

This is my replacement for [macos' spotlight](https://en.wikipedia.org/wiki/Spotlight_(Apple)). It runs as a background app and can be summoned with <kbd>Cmd</kbd> + <kbd>Space</kbd>.

## Disclaimer

limelight is written completely for myself. I'm making a variant of the code available here so I have somewhere to point people to.

I am NOT providing support for this code in any way shape or form. Do not open issues or pull requests; they will be closed.

In fact, I recommend you don't use this code at all!

## Why

99% of the time I use spotlight to search for a local file. I almost never use it to search file contents, and I certainly don't want it to split results into "documents", "music", "spreadsheets", and who knows what else. I don't know who at apple decided a dedicated "fonts" section was a good idea.

Setting presentation aside, even the basic functionality of spotlight has some issues:

* \>500ms response times for name matches against local files
* incorrect results for certain unicode characters
  * try creating a file called ・－・.txt and searching for it with spotlight (spoiler: it can't find it)

It really should not be this hard for macos to provide an application which displays exact filename matches in <100ms (ideally <30ms)! The fact that spotlight cannot do this is the primary motivation for limelight.

That said, spotlight is a good piece of technology which does what 90% of users want 90% of the time. If that's you, don't let me dissuade you from it.


## Bonuses

Along the way, "reimplement spotlight" turned into "wouldn't it be cool if I added that to spotlight?" And that's how limelight now has reverse polish notation, syntax for searching inside a particular directory (recursively or not), a vscode-style command palette (with `>`), and a bunch of other random stuff I find useful and/or cool.
