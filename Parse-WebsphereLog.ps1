# Load necessary .NET assemblies for the GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Define the Regular Expression ---
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
$listView.View = 'Details'
$listView.GridLines = $true
$listView.FullRowSelect = $true
$listView.Location = New-Object System.Drawing.Point(10, 45)
$listView.Size = New-Object System.Drawing.Size(($form.ClientSize.Width - 20), ($form.ClientSize.Height - 60))
$listView.Anchor = 'Top, Bottom, Left, Right'

# Define the Columns for the ListView
$listView.Columns.Add("Timestamp", 160) | Out-Null
$listView.Columns.Add("Thread ID", 100) | Out-Null
$listView.Columns.Add("Logger", 150) | Out-Null
$listView.Columns.Add("Level", 50, 'Center') | Out-Null
$listView.Columns.Add("Message", 700) | Out-Null

# --- Define the Action for the Button Click ---
$button.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Title = "Select a WebSphere Log File"
    $openFileDialog.Filter = "Log Files (*.log)|*.log|Output Files (*.out)|*.out|All files (*.*)|*.*"

    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $filePath = $openFileDialog.FileName
        
        $listView.Items.Clear()
        $form.Text = "Parsing: $filePath"
        
        try {
            $content = Get-Content -Path $filePath -Raw
            $matches = [regex]::Matches($content, $logRegex)
            
            # Counter to track when to update the UI
            $updateCounter = 0

            foreach ($match in $matches) {
                # Create a new row (ListViewItem)
                $item = New-Object System.Windows.Forms.ListViewItem($match.Groups['timestamp'].Value)
                
                # Add the other fields
                $item.SubItems.Add($match.Groups['thread'].Value) | Out-Null
                $item.SubItems.Add($match.Groups['logger'].Value) | Out-Null
                $item.SubItems.Add($match.Groups['level'].Value) | Out-Null
                $item.SubItems.Add($match.Groups['message'].Value.Trim()) | Out-Null
                
                # Add the completed row to the list view
                $listView.Items.Add($item) | Out-Null
                
                # --- NEW: This is the responsiveness logic ---
                $updateCounter++
                # Every 100 records, force the UI to update
                if ($updateCounter % 100 -eq 0) {
                    # Update the window title with the current count
                    $form.Text = "Parsing... $($listView.Items.Count) records found"
                    # Process pending UI events to make the new records appear
                    [System.Windows.Forms.Application]::DoEvents()
                }
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("An error occurred while reading or parsing the file: `n$($_.Exception.Message)", "Error", "OK", "Error")
        }
        finally {
            # Final update to the window title
            $form.Text = "PowerShell WebSphere Log Parser - $($matches.Count) records loaded"
        }
    }
})

# Add the Controls to the Form
$form.Controls.Add($button)
$form.Controls.Add($listView)

# Show the Form
[void]$form.ShowDialog()
