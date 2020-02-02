const fs = require('fs').promises;
const path = require('path');
const express = require('express');
const bodyParser = require('body-parser');
const Diff = require('diff');

const app = express();
app.use(bodyParser.text());
app.listen(4096);

function diff(local, remote) {
    const diff = Diff.diffLines(remote, local);
    const prepend = (prefix, value) => (
        value.trim().split('\n').map(d => prefix + d).join('\n')
    );
    console.log(local, remote);
    return diff.map(item => {
        if (item.added) {
            return prepend('+ ', item.value);
        } else if (item.removed) {
            return prepend('- ', item.value);
        } else {
            return item.value.trim();
        }
    }).join('\n');
}

function merge(local, remote) {
    const diff = Diff.diffLines(remote, local);
    const prepend = (prefix, value) => (
        value.trim().split('\n').map(d => prefix + d).join('\n')
    );
    return diff.map(item => {
        return item.value.trim();
    }).join('\n');
}

(async () => {
    const exists = async (dir) => !!await fs.stat(dir).catch(_ => false);
    const dir = path.join(__dirname, '/notes');
    if (!await exists(dir)) {
        await fs.mkdir(dir);
    }

    app.use('*', (req, res, next) => {
        req.getPath = () => (
            path.join(dir, (req.params.name || '').replace(/[^a-zA-Z0-9\s]+/g, ''))
        );
        res.set('Content-Type', 'text/plain')
        next();
    });

    app.post('/ns/:name', async (req, res) => {
        const notePath = req.getPath();
        const note = await exists(notePath) ? await fs.readFile(notePath, 'utf8') : '';
        res.send(diff(note, req.body));
    });

    app.post('/nd/:name', async (req, res) => {
        const notePath = req.getPath();
        const note = await exists(notePath) ? await fs.readFile(notePath, 'utf8') : '';
        res.send(merge(note, req.body));
    });

    app.post('/nw/:name', async (req, res) => {
        const notePath = req.getPath();
        await fs.writeFile(notePath, req.body, 'utf8');
        res.end();
    });

    app.post('/list', async (req, res) => {
        const server = (await fs.readdir(dir)).join('\n');
        const vim = req.body.replace(/\//g, '\n');
        res.send(diff(server, vim));
    });

    // :NList
    // ;NDiff
    // ;NPush
    // if no password, check for password

    // diff two files

    // MERGE on post
    // just show conflict if it exists

// get
// set
// list
// auth

})();
