
const fs = require('fs');
const path = require('path');
const child = require('child_process');

const yaml = require('js-yaml');

const check = require('offensive').default;
require('offensive/assertions/allElementsThat/register');
require('offensive/assertions/fieldThat/register');
require('offensive/assertions/aString/register');
require('offensive/assertions/allElementsThat/register');

const WORKSPACE = `${__dirname}/workspace/`;
const RUN_SCRIPT = `${__dirname}/run.sh`;

cwd(__dirname);
const config = readConfigFile();
cwd(WORKSPACE);

// nice padding
console.log('')

const status = config.pkgs
  .map(run)
  .reduce((a, b) => a + b);
process.exit(status);

function log(msg) {
  process.stdout.write(msg);
}

function cwd(dir) {
  console.info(`cwd: ${dir}`);
  process.cwd(dir);
}

function readConfigFile() {
  const config = yaml.safeLoad(fs.readFileSync('./config.yml', 'utf-8'));

  log('Validating config.yml');
  check(config, 'config')
    .has.fieldThat('pkgs', field => field
      .contains.allElementsThat(elem => elem
        .has.fieldThat('name', name => name.is.aString)
        .and.fieldThat('repoUrl', repoUrl => repoUrl.is.aString)
        .and.fieldThat('pwdVar', pwdVar => pwdVar.is.aString)
        .and.fieldThat('testTask', testTask => testTask.is.aString)
        .and.fieldThat('deployTask', deployTask => deployTask.is.aString.or.Undefined)
      )
    )
    ()
  ;
  log(' ✔\n');
  return config;
}

function run(pkg) {
  const childProc = child.spawnSync(
    RUN_SCRIPT,
    [pkg.name, pkg.repoUrl, pkg.pwdVar, pkg.testTask, pkg.deployTask || ""],
    {
      stdio: 'inherit',
      cwd: WORKSPACE,
      env: {
        PATH: `${path.join(__dirname, 'node_modules/.bin')}:${process.env.PATH}`,
        [pkg.pwdVar]: process.env[pkg.pwdVar],
        USER: process.env.USER,
        HOME: process.env.HOME,
      },
    },
  );

  if (childProc.error) {
    log(`${childProc.error.message}\n`);
  }
  if (childProc.status !== 0) {
    log(`Child process returned ${childProc.status}\n`);
  }
  if (childProc.stderr) {
    log('Child process stderr:\n');
    log(`${childProc.stderr}\n`);
  }
  log('\n---\n\n');
  return childProc.status;
}

