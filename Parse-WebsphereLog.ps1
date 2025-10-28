# Load necessary .NET assemblies for the GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Define the Regular Expression ---
# The (?m) at the start enables multiline mode, which is crucial for this regex to work.
$logRegex = '(?m)^\[(?<timestamp>\d{1,2}\/\d{1,2}\/\d{2}\s\d{1,2}:\d{2}:\d{2}:\d{3}\s[A-Z]{3})\]\s+(?<thread>[0-9a-fA-F]+)\s+(?<logger>\S+)\s+(?<level>[A-Z])\s+(?<message>[\s\S]+?)(?=\n^\[\d{1,2}\/\d{1,2}\/\d{2}|\Z)'

# --- Build the Main Form (Window) ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "PowerShell WebSphere Log Parser"
$form.Size = New-Object System.Drawing.Size(1200, 700)
$form.StartPosition = 'CenterScreen'

# --- Create the "Load Log File" Button ---
$button = New-Object System.Windows.Forms.Button
$button.Text = "Load Log File..."
$button.Location = New-Object System.Drawing.Point(10, 10)
$button.AutoSize = $true

# --- Create the ListView (Grid View) ---
$listView = New-Object System.Windows.Forms.ListView
$listView.View = 'Details' # This enables the grid-like view
$listView.GridLines = $true
$listView.FullRowSelect = $true
$listView.Location = New-Object System.Drawing.Point(10, 45)
# Set the size relative to the form, leaving space for the button
$listView.Size = New-Object System.Drawing.Size(($form.ClientSize.Width - 20), ($form.ClientSize.Height - 60))
# Anchor the listview to all sides so it resizes with the window
$listView.Anchor = 'Top, Bottom, Left, Right'

# --- Define the Columns for the ListView ---
$listView.Columns.Add("Timestamp", 160) | Out-Null
$listView.Columns.Add("Thread ID", 100) | Out-Null
$listView.Columns.Add("Logger", 150) | Out-Null
$listView.Columns.Add("Level", 50, 'Center') | Out-Null
$listView.Columns.Add("Message", 700) | Out-Null

# --- Define the Action for the Button Click ---
$button.Add_Click({
    # Create the file dialog
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Title = "Select a WebSphere Log File"
    $openFileDialog.Filter = "Log Files (*.log)|*.log|Output Files (*.out)|*.out|All files (*.*)|*.*"

    # Show the dialog and check if the user clicked "OK"
    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $filePath = $openFileDialog.FileName
        
        # Clear any previous results from the list view
        $listView.Items.Clear()
        $form.Text = "Parsing: $filePath" # Update window title
        
        try {
            # Read the entire file content at once
            $content = Get-Content -Path $filePath -Raw
            
            # Find all matches using the regex
            $matches = [regex]::Matches($content, $logRegex)
            
            # Use BeginUpdate/EndUpdate for much faster loading
            $listView.BeginUpdate()

            foreach ($match in $matches) {
                # Create a new row (ListViewItem)
                $item = New-Object System.Windows.Forms.ListViewItem($match.Groups['timestamp'].Value)
                
                # Add the other fields as sub-items (columns)
                $item.SubItems.Add($match.Groups['thread'].Value) | Out-Null
                $item.SubItems.Add($match.Groups['logger'].Value) | Out-Null
                $item.SubItems.Add($match.Groups['level'].Value) | Out-Null
                $item.SubItems.Add($match.Groups['message'].Value.Trim()) | Out-Null # Trim whitespace from the message
                
                # Add the completed row to the list view
                $listView.Items.Add($item) | Out-Null
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("An error occurred while reading or parsing the file: `n$($_.Exception.Message)", "Error", "OK", "Error")
        }
        finally {
            $listView.EndUpdate()
            $form.Text = "PowerShell WebSphere Log Parser - $($matches.Count) records loaded"
        }
    }
})

# --- Add the Controls to the Form ---
$form.Controls.Add($button)
$form.Controls.Add($listView)

# --- Show the Form ---
# The [void] cast prevents unwanted status output to the console.
[void]$form.ShowDialog()
