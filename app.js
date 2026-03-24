require('dotenv').config();
const express = require("express");
const { spawn, exec } = require("child_process");
const app = express();
app.use(express.json());
const commandToRun = "cd ~ && bash serv00keep.sh";
function runCustomCommand() {
    exec(commandToRun, (err, stdout, stderr) => {
        if (err) console.error("Execution error:", err);
        else console.log("Execution successful:", stdout);
    });
}
app.get("/up", (req, res) => {
    runCustomCommand();
    res.type("html").send("<pre>Serv00-name server web keep-alive started: Serv00-name! UP! UP! UP!</pre>");
});
app.get("/re", (req, res) => {
    const additionalCommands = `
        USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
        FULL_PATH="/home/\${USERNAME}/domains/\${USERNAME}.serv00.net/logs"
        cd "\$FULL_PATH"
        pkill -f 'run -c con' || echo "No process to terminate, preparing to restart..."
        sbb="\$(cat sb.txt 2>/dev/null)"
        nohup ./"\$sbb" run -c config.json >/dev/null 2>&1 &
        sleep 2
        (cd ~ && bash serv00keep.sh >/dev/null 2>&1) &  
        echo 'Main program restarted successfully. Please check if the three main nodes are available. If not, refresh the restart page again or reset the ports.'
    `;
    exec(additionalCommands, (err, stdout, stderr) => {
        console.log('stdout:', stdout);
        console.error('stderr:', stderr);
        if (err) {
            return res.status(500).send(`Error: ${stderr || stdout}`);
        }
        res.type('text').send(stdout);
    });
}); 

const changeportCommands = "cd ~ && bash webport.sh"; 
function runportCommand() {
exec(changeportCommands, { maxBuffer: 1024 * 1024 * 10 }, (err, stdout, stderr) => {
        console.log('stdout:', stdout);
        console.error('stderr:', stderr);
        if (err) {
            console.error('Execution error:', err);
            return res.status(500).send(`Error: ${stderr || stdout}`);
        }
        if (stderr) {
            console.error('stderr output:', stderr);
            return res.status(500).send(`stderr: ${stderr}`);
        }
        res.type('text').send(stdout);
    });
}
app.get("/rp", (req, res) => {
   runportCommand();  
   res.type("html").send("<pre>Three node ports reset completed! Please close this page immediately and wait 20 seconds, then change the main page suffix to /list/your-uuid to view the updated node and subscription information.</pre>");
});
app.get("/list/key", (req, res) => {
    const listCommands = `
        USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
        USERNAME1=$(whoami)
        FULL_PATH="/home/\${USERNAME1}/domains/\${USERNAME}.serv00.net/logs/list.txt"
        cat "\$FULL_PATH"
    `;
    exec(listCommands, (err, stdout, stderr) => {
        if (err) {
            console.error(`Path verification failed: ${stderr}`);
            return res.status(404).send(stderr);
        }
        res.type('text').send(stdout);
    });
});

app.get("/jc", (req, res) => {
    const ps = spawn("ps", ["aux"]);
    res.type("text");
    ps.stdout.on("data", (data) => res.write(data));
    ps.stderr.on("data", (data) => res.write(`Error: ${data}`));
    ps.on("close", (code) => {
        if (code !== 0) {
            res.status(500).send(`ps aux process exited with error code: ${code}`);
        } else {
            res.end();
        }
    });
});

app.use((req, res) => {
    res.status(404).send('Please add one of the following paths after http://where.name.serv00.net: /up for keep-alive, /re for restart, /rp for reset node ports, /jc for view system processes, /list/your-uuid for node and subscription info');
});
setInterval(runCustomCommand, (2 * 60 + 15) * 60 * 1000);
app.listen(3000, () => {
    console.log("Server running on port 3000");
    runCustomCommand();
});
