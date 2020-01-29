const fs = require('fs').promises;
const path = require('path');
const express = require('express');
const bodyParser = require('body-parser');

const app = express();
app.use(bodyParser.json());
app.listen(4096);

(async () => {
    const exists = async (dir) => !!await fs.stat(dir).catch(_ => false);
    const dir = path.join(__dirname, '/notes');
    if (!await exists(dir)) {
        await fs.mkdir(dir);
    }

    app.use('*', (req, res, next) => {
        req.params.name = (req.params.name || '').replace(/^[a-zA-Z0-9\s]+$/, '');
        res.set('Content-Type', 'text/plain')
        next();
    });

    app.get('/n/:name', async (req, res) => {
        const notePath = path.join(dir, req.params.name)
        if (await exists(notePath)) {
            res.send(await fs.readFile(notePath, 'utf8'));
        } else {
            await fs.writeFile(notePath, '', 'utf8')
            res.send('');
        }
    });

    app.get('/n/:name', async (req, res) => {
        const notePath = path.join(dir, req.params.name)
        if (await exists(notePath)) {
            console.log('todo: merge');
        } else {
        }
        await fs.writeFile(notePath, req.body, 'utf8')
    });

    app.get('/list', async (req, res) => {
        res.send((await fs.readdir(dir)).join('\n'));
    });

    // :NList
    // if no password, check for password

    // diff two files

    // MERGE on post
    // just show conflict if it exists

// get
// set
// list
// auth

})();
