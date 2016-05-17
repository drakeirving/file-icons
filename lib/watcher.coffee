{CompositeDisposable} = require "./utils"

# Controller to manage auxiliary event subscriptions
class Watcher
	
	constructor: ->
		@editors     = new Set
		@repos       = new Set
		
		@editorDisposables = new CompositeDisposable
		@repoDisposables   = new CompositeDisposable
	
	
	# Set whether the project's VCS repositories are being monitored for changes
	watchingRepos: (enabled) ->
		if enabled
			repos = atom.project.getRepositories()
			@watchRepo(i) for i in repos when i
		else
			@repos.clear()
			@repoDisposables.dispose()
			@repoDisposables = new CompositeDisposable
	
	
	# Register a repository with the watcher, if it hasn't been already
	watchRepo: (repo) ->
		unless @repos.has repo
			@repos.add repo
			
			@repoDisposables.add repo.onDidChangeStatus (event) => @onRepoUpdate?(event)
			@repoDisposables.add repo.onDidChangeStatuses       => @onRepoUpdate?()
			
			# When repository's removed from memory
			@repoDisposables.add repo.onDidDestroy =>
				@repos.delete repo
				unless @repos.size
					@repoDisposables.dispose()
					@repoDisposables = new CompositeDisposable
			
	
	
	# Set whether editors are being monitored for certain events
	watchingEditors: (enabled) ->
		if enabled
			editors = atom.workspace.getTextEditors()
			
			# Even though observeTextEditors fires for currently-open editors, race
			# conditions with package-loading make execution order unreliable.
			@watchEditor(i) for i in editors
			
			# Set a listener to register the editor only after it's finished initialising.
			# The grammar-change event still fires when an editor's opened.
			@editorDisposables.add atom.workspace.observeTextEditors (editor) =>
				return if @editors.has(editor)
				once = editor.onDidStopChanging =>
					console.log "onDidStopChanging: #{editor.getFileName()}"
					@watchEditor(editor)
					once.dispose()

		else
			@editors.clear()
			@editorDisposables.dispose()
			@editorDisposables = new CompositeDisposable
	
	
	# Attach listeners to a TextEditor, unless it was already done
	watchEditor: (editor) ->
		unless @editors.has editor
			console.trace "Watching editor: #{editor.getFileName()}"
			@editors.add editor
			onChange = editor.onDidChangeGrammar (to) => @onGrammarChange?(to)
			onDestroy = editor.onDidDestroy =>
				@editors.delete editor
				@editorDisposables.remove(i) for i in [onChange, onDestroy]
				onChange.dispose()
				onDestroy.dispose()
			@editorDisposables.add onChange
			@editorDisposables.add onDestroy
			
		
		
module.exports = Watcher
