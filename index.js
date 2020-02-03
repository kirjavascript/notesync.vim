const fs = require('fs').promises;
const path = require('path');
const express = require('express');
const bodyParser = require('body-parser');
const Diff = require('diff');

const app = express();
app.use(bodyParser.text());
app.listen(4096);

function diff(local, remote) {
    const diff = Diff.diffLines(remote + '\n', local + '\n');
    const prepend = (prefix, value) => (
        value.trim().split('\n').map(d => prefix + d).join('\n')
    );
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

(async () => {
    const exists = async (dir) => !!await fs.stat(dir).catch(_ => false);
    const dir = path.join(__dirname, '/notes');
    const keyPath = path.join(__dirname, '/.key');
    if (!await exists(dir)) {
        await fs.mkdir(dir);
    }

    if (!await exists(keyPath)) {
        console.log('secret key missing');
        process.exit(0);
    }

    const key = (await fs.readFile(keyPath, 'utf8')).trim();

    const basicAuth = /^\s*basic\s+(.+)$/i
    app.use('*', (req, res, next) => {
        const Xauth = req.headers['x-authorization'];
        const authorization = Xauth || req.headers.authorization;
        if (authorization && basicAuth.test(authorization)) {
            const [, creds] = authorization.match(basicAuth);
            const credsString = Buffer.from(creds, 'base64').toString();
            const [, password] = credsString.match(/^(?:[^:]*):(.*)$/);
            if (password !== key) {
                res.status(401).send('401');
            } else {
                next();
            }
        } else {
            res.status(401).send('401');
        }
    });

    app.use('*', (req, res, next) => {
        req.getPath = () => (
            path.join(dir, '/' + (req.params.name.replace(/\+/g, ' ') || '')
                .replace(/[^a-zA-Z0-9\s]+/g, ''))
        );
        res.set('Content-Type', 'text/plain')
        next();
    });

    app.get('/n/:name', async (req, res) => {
        const notePath = req.getPath();
        const note = await exists(notePath) ? await fs.readFile(notePath, 'utf8') : '';
        res.send(note);
    });

    app.get('/d/:name', async (req, res) => {
        const notePath = req.getPath();
        await fs.unlink(notePath);
        res.end();
    });

    const view = (path, callback) => {
        app.post(path, async (req, res) => {
            const notePath = req.getPath();
            const note = await exists(notePath) ? await fs.readFile(notePath, 'utf8') : '';
            callback(note, req, res)
        });
    }

    view('/ns/:name', (note, req, res) => {
        res.send(diff(note, req.body));
    });

    // both
    view('/nd/:name', (note, req, res) => {
        const diff = Diff.diffLines(note, req.body);
        res.send(diff.ap(item => item.value.trim()).join('\n'));
    });

    // added
    view('/nf/:name', (note, req, res) => {
        const diff = Diff.diffLines(note, req.body);
        res.send(diff.filter(d => d.added).map(item => item.value.trim()).join('\n'));
    });

    // removed
    view('/ng/:name', (note, req, res) => {
        const diff = Diff.diffLines(note, req.body);
        res.send(diff.filter(d => d.removed).map(item => item.value.trim()).join('\n'));
    });

    // remote
    view('/nh/:name', (note, _req, res) => {
        res.send(note);
    });

    // push
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

})();
